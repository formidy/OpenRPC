"""
OpenRPC Bridge v2.0.0
A modular bridge server for Discord Rich Presence integration

I don't exactly advise using this in production, but this is just to show how to communicate with the luau script. 
I would personally create a main app, if viable, to run in background after setup, or let the user decide, etc, to act as a main dashboard. I would only see this used in serious exploits or 
side projects anyway. You can figure out a solution yourself if you wish.
"""

from pypresence import Presence
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional, Dict, Any, Callable
import json
import time
import sys
import logging
from dataclasses import dataclass


@dataclass
class BridgeConfig:
    """Bridge configuration"""
    port: int = 8080
    client_id: str = "1436600503692824586"
    log_level: str = "INFO"
    verbose: bool = False


class OpenRPC:
    """Discord RPC Bridge handler"""
    
    def __init__(self, config: Optional[BridgeConfig] = None):
        self.config = config or BridgeConfig()
        self.rpc: Optional[Presence] = None
        self.start_time: int = int(time.time())
        self.connected: bool = False
        self.update_count: int = 0
        
        self._setup_logging()
        
    def _setup_logging(self) -> None:
        """Setup logging configuration"""
        level = getattr(logging, self.config.log_level.upper(), logging.INFO)
        
        format_str = "%(levelname)s - %(message)s" if not self.config.verbose else \
                     "%(asctime)s [%(levelname)s] %(message)s"
        
        logging.basicConfig(
            level=level,
            format=format_str,
            datefmt="%H:%M:%S"
        )
        
        self.logger = logging.getLogger("OpenRPC")
    
    def connect(self) -> bool:
        """Connect to Discord RPC"""
        try:
            self.logger.info("Connecting to Discord RPC...")
            self.rpc = Presence(self.config.client_id)
            self.rpc.connect()
            self.connected = True
            self.logger.info("✅ Connected to Discord!")
            return True
        except Exception as e:
            self.logger.error(f"❌ Failed to connect: {e}")
            return False
    
    def update(self, data: Dict[str, Any]) -> bool:
        """Update Discord presence"""
        if not self.rpc or not self.connected:
            self.logger.error("Not connected to Discord")
            return False
        
        try:
            buttons = []
            if data.get('url'):
                buttons.append({'label': 'Join Game', 'url': data['url']})
            if data.get('profile_url') and len(buttons) < 2:
                buttons.append({'label': 'View Profile', 'url': data['profile_url']})
            
            update_data = {
                'details': data.get('details', 'Playing Roblox')[:128],
                'state': data.get('state', 'In Game')[:128],
                'start': self.start_time,
            }
            
            if data.get('large_image'):
                update_data['large_image'] = data['large_image']
                update_data['large_text'] = data.get('large_text', 'Roblox')[:128]
            
            if data.get('small_image'):
                update_data['small_image'] = data['small_image']
                update_data['small_text'] = data.get('small_text', 'Player')[:128]
            
            if buttons:
                update_data['buttons'] = buttons[:2]
            
            self.rpc.update(**update_data)
            self.update_count += 1
            
            if self.config.verbose:
                self.logger.info(f"Updated #{self.update_count}: {data.get('details', 'N/A')}")
            else:
                self.logger.debug(f"Updated: {data.get('details', 'N/A')}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Update failed: {e}")
            return False
    
    def disconnect(self) -> None:
        """Disconnect from Discord RPC"""
        if self.rpc:
            try:
                self.rpc.clear()
                self.rpc.close()
                self.connected = False
                self.logger.info("Disconnected from Discord")
            except Exception as e:
                self.logger.error(f"Error during disconnect: {e}")
    
    def create_handler(self) -> type:
        """Create HTTP request handler"""
        bridge = self
        
        class BridgeHandler(BaseHTTPRequestHandler):
            def log_message(self, format, *args):
                """Suppress default logging"""
                pass
            
            def do_POST(self):
                try:
                    length = int(self.headers.get('Content-Length', 0))
                    data = json.loads(self.rfile.read(length)) if length > 0 else {}
                    
                    success = bridge.update(data)
                    
                    self.send_response(200 if success else 500)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {'success': success}
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    bridge.logger.error(f"Request error: {e}")
                    self.send_response(500)
                    self.end_headers()
            
            def do_GET(self):
                if self.path == '/health':
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    status = {
                        'status': 'ok',
                        'connected': bridge.connected,
                        'updates': bridge.update_count,
                        'uptime': int(time.time() - bridge.start_time)
                    }
                    self.wfile.write(json.dumps(status).encode())
                elif self.path == '/stats':
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    
                    stats = {
                        'version': '2.0.0',
                        'port': bridge.config.port,
                        'client_id': bridge.config.client_id,
                        'update_count': bridge.update_count,
                        'uptime': int(time.time() - bridge.start_time),
                        'connected': bridge.connected
                    }
                    self.wfile.write(json.dumps(stats).encode())
                else:
                    self.send_response(404)
                    self.end_headers()
            
            def do_OPTIONS(self):
                self.send_response(200)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', 'Content-Type')
                self.end_headers()
        
        return BridgeHandler
    
    def run(self) -> None:
        """Run the bridge server"""
        if not self.connect():
            sys.exit(1)
        
        try:
            server = HTTPServer(('127.0.0.1', self.config.port), self.create_handler())
            self.logger.info(f"Listening on http://127.0.0.1:{self.config.port}")
            self.logger.info("Press Ctrl+C to stop\n")
            server.serve_forever()
            
        except KeyboardInterrupt:
            self.logger.info("\n\nShutting down...")
            self.disconnect()
            sys.exit(0)
            
        except OSError as e:
            if "already in use" in str(e).lower():
                self.logger.error(f"❌ Port {self.config.port} is already in use!")
                self.logger.error(f"Kill it: lsof -ti:{self.config.port} | xargs kill -9")
            else:
                self.logger.error(f"❌ Server error: {e}")
            sys.exit(1)


def main():
    """Main entry point for standalone usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Discord RPC Bridge Server")
    parser.add_argument('-p', '--port', type=int, default=8080, help='Server port (default: 8080)')
    parser.add_argument('-c', '--client-id', type=str, default="1436600503692824586", help='Discord Client ID')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose logging')
    parser.add_argument('-l', '--log-level', type=str, default='INFO', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], help='Log level')
    
    args = parser.parse_args()
    
    config = BridgeConfig(
        port=args.port,
        client_id=args.client_id,
        log_level=args.log_level,
        verbose=args.verbose
    )
    
    bridge = OpenRPC(config)
    bridge.run()


if __name__ == '__main__':
    main()
