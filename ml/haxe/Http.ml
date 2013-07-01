package haxe {
	import sys.net.Socket;
	import haxe.io.Eof;
	import haxe.io.Bytes;
	import haxe.io.BytesOutput;
	import haxe.io.BytesBuffer;
	import haxe.ds.StringMap;
	import sys.net.Host;
	import haxe.io._Error;
	import flash.Boot;
	import haxe.io.Output;
class Http =;
	object;
		public function Http(url : String = null) : unit ( if( !flash.Boot.skip_constructor ) {
			this.url = url;
			this.headers = new haxe.ds.StringMap();
			this.params = new haxe.ds.StringMap();
			this.cnxTimeout = 10;
		});
		
		public var onStatus : int32 -> unit = function(status : int32) : unit (;
		);
		public var onError : String -> unit = function(msg : String) : unit (;
		);
		public var onData : String -> unit = function(data : String) : unit (;
		);
		protected function readChunk(chunk_re : EReg,api : haxe.io.Output,buf : haxe.io.Bytes,len : int32) : bool (;
			if(this.chunk_size == null) (;
				if(this.chunk_buf != null) (;
					let b : haxe.io.BytesBuffer = new haxe.io.BytesBuffer() in;
					(;
						let src : haxe.io.Bytes = this.chunk_buf in;
						let b1 : List = b.b in;
						let b2 : List = src.b in;
						(;
							let _g1 : int32 = 0 in;
							let _g : int32 = src.length in;
							while(_g1 < _g) (;
								let i : int32 = _g1++ in;
								b.b.push(b2[i]);
							);
						);
					);
					(;
						if(len < 0 || len > buf.length) throw haxe.io._Error.OutsideBounds;
						let b1 : List = b.b in;
						let b2 : List = buf.b in;
						(;
							let _g1 : int32 = 0 in;
							let _g : int32 = len in;
							while(_g1 < _g) (;
								let i : int32 = _g1++ in;
								b.b.push(b2[i]);
							);
						);
					);
					buf = b.getBytes();
					len += this.chunk_buf.length;
					this.chunk_buf = null;
				);
				if(chunk_re.match(buf.toString())) (;
					let p : * = chunk_re.matchedPos() in;
					if(p.len <= len) (;
						let cstr : String = chunk_re.matched(1) in;
						this.chunk_size = Std._parseInt("0x" + cstr);
						if(cstr == "0") (;
							this.chunk_size = null;
							this.chunk_buf = null;
							return false;
						);
						len -= p.len;
						return this.readChunk(chunk_re,api,buf.sub(p.len,len),len);
					);
				);
				if(len > 10) (;
					this.onError("Invalid chunk");
					return false;
				);
				this.chunk_buf = buf.sub(0,len);
				return true;
			);
			if(this.chunk_size > len) (;
				this.chunk_size -= len;
				api.writeBytes(buf,0,len);
				return true;
			);
			let end : int32 = this.chunk_size + 2 in;
			if(len >= end) (;
				if(this.chunk_size > 0) api.writeBytes(buf,0,this.chunk_size);
				len -= end;
				this.chunk_size = null;
				if(len == 0) return true;
				return this.readChunk(chunk_re,api,buf.sub(end,len),len);
			);
			if(this.chunk_size > 0) api.writeBytes(buf,0,this.chunk_size);
			this.chunk_size -= len;
			return true;
		);
		
		protected function readHttpResponse(api : haxe.io.Output,sock : *) : unit (;
			let b : haxe.io.BytesBuffer = new haxe.io.BytesBuffer() in;
			let k : int32 = 4 in;
			let s : haxe.io.Bytes = haxe.io.Bytes.alloc(4) in;
			sock.setTimeout(this.cnxTimeout);
			try {
				while(true) (;
					let p : int32 = sock.input.readBytes(s,0,k) in;
					while(p != k) p += sock.input.readBytes(s,p,k - p);
					(;
						if(k < 0 || k > s.length) throw haxe.io._Error.OutsideBounds;
						let b1 : List = b.b in;
						let b2 : List = s.b in;
						(;
							let _g1 : int32 = 0 in;
							let _g : int32 = k in;
							while(_g1 < _g) (;
								let i : int32 = _g1++ in;
								b.b.push(b2[i]);
							);
						);
					);
					switch(k) {
					case 1:
					(;
						let c : int32 = s.b[0] in;
						if(c == 10) throw "__break__";
						if(c == 13) k = 3;
						else k = 4;
					);
					break;
					case 2:
					(;
						let c : int32 = s.b[1] in;
						if(c == 10) (;
							if(s.b[0] == 13) throw "__break__";
							k = 4;
						);
						else if(c == 13) k = 3;
						else k = 4;
					);
					break;
					case 3:
					(;
						let c : int32 = s.b[2] in;
						if(c == 10) (;
							if(s.b[1] != 13) k = 4;
							else if(s.b[0] != 10) k = 2;
							else throw "__break__";
						);
						else if(c == 13) (;
							if(s.b[1] != 10 || s.b[0] != 13) k = 1;
							else k = 3;
						);
						else k = 4;
					);
					break;
					case 4:
					(;
						let c : int32 = s.b[3] in;
						if(c == 10) (;
							if(s.b[2] != 13) continue;
							else if(s.b[1] != 10 || s.b[0] != 13) k = 2;
							else throw "__break__";
						);
						else if(c == 13) (;
							if(s.b[2] != 10 || s.b[1] != 13) k = 3;
							else k = 1;
						);
					);
					break;
					}
				);
			} catch( e : * ) { if( e != "__break__" ) throw e; };
			let headers : List = b.getBytes().toString().split("\r\n") in;
			let response : String = headers.shift() in;
			let rp : List = response.split(" ") in;
			let status : * = Std._parseInt(rp[1]) in;
			if(status == 0 || status == null) throw "Response status error";
			headers.pop();
			headers.pop();
			this.responseHeaders = new haxe.ds.StringMap();
			let size : * = null in;
			let chunked : bool = false in;
			(;
				let _g : int32 = 0 in;
				while(_g < headers.length) (;
					let hline : String = headers[_g] in;
					++_g;
					let a : List = hline.split(": ") in;
					let hname : String = a.shift() in;
					let hval : String = () in;
					if(a.length == 1) hval = a[0];
					else hval = a.join(": ");
					this.responseHeaders.set(hname,hval);
					(;
						let _g1 : String = hname.toLowerCase() in;
						switch(_g1) {
						case "content-length":
						size = Std._parseInt(hval);
						break;
						case "transfer-encoding":
						chunked = hval.toLowerCase() == "chunked";
						break;
						}
					);
				);
			);
			this.onStatus(status);
			let chunk_re : EReg = new EReg("^([0-9A-Fa-f]+)[ ]*\r\n","m") in;
			this.chunk_size = null;
			this.chunk_buf = null;
			let bufsize : int32 = 1024 in;
			let buf : haxe.io.Bytes = haxe.io.Bytes.alloc(bufsize) in;
			if(size == null) (;
				if(!this.noShutdown) sock.shutdown(false,true);
				try (;
					while(true) (;
						let len : int32 = sock.input.readBytes(buf,0,bufsize) in;
						if(chunked) (;
							if(!this.readChunk(chunk_re,api,buf,len)) break;
						);
						else api.writeBytes(buf,0,len);
					);
				);
				catch( e : haxe.io.Eof )(;
				);
			);
			else (;
				api.prepare(size);
				try (;
					while(size > 0) (;
						let len : int32 = sock.input.readBytes(buf,0,((size > bufsize)?bufsize:size)) in;
						if(chunked) (;
							if(!this.readChunk(chunk_re,api,buf,len)) break;
						);
						else api.writeBytes(buf,0,len);
						size -= len;
					);
				);
				catch( e : haxe.io.Eof )(;
					throw "Transfert aborted";
				);
			);
			if(chunked && (this.chunk_size != null || this.chunk_buf != null)) throw "Invalid chunk";
			if(status < 200 || status >= 400) throw "Http Error #" + status;
			api.close();
		);
		
		public function customRequest(post : bool,api : haxe.io.Output,sock : * = null,method : String = null) : unit (;
			this.responseData = null;
			let url_regexp : EReg = new EReg("^(https?://)?([a-zA-Z\\.0-9-]+)(:[0-9]+)?(.*)$","") in;
			if(!url_regexp.match(this.url)) (;
				this.onError("Invalid URL");
				return;
			);
			let secure : bool = url_regexp.matched(1) == "https://" in;
			if(sock == null) (;
				if(secure) throw "Https is only supported with -lib hxssl";
				else sock = new sys.net.Socket();
			);
			let host : String = url_regexp.matched(2) in;
			let portString : String = url_regexp.matched(3) in;
			let request : String = url_regexp.matched(4) in;
			if(request == "") request = "/";
			let port : * = () in;
			if(portString == null || portString == "") (;
				if(secure) port = 443;
				else port = 80;
			);
			else port = Std._parseInt(portString.substr(1,portString.length - 1));
			let data : * = () in;
			let multipart : bool = this.file != null in;
			let boundary : String = null in;
			let uri : String = null in;
			if(multipart) (;
				post = true;
				boundary = Std.string(Std.random(1000)) + Std.string(Std.random(1000)) + Std.string(Std.random(1000)) + Std.string(Std.random(1000));
				while(boundary.length < 38) boundary = "-" + boundary;
				let b : StringBuf = new StringBuf() in;
				{ var $it : * = this.params.keys();
				while( $it.hasNext() ) { var p : String = $it.next();
				(;
					b.b += "--";
					b.b += Std.string(boundary);
					b.b += "\r\n";
					b.b += "Content-Disposition: form-data; name=\"";
					b.b += Std.string(p);
					b.b += "\"";
					b.b += "\r\n";
					b.b += "\r\n";
					b.b += Std.string(this.params.get(p));
					b.b += "\r\n";
				);
				}};
				b.b += "--";
				b.b += Std.string(boundary);
				b.b += "\r\n";
				b.b += "Content-Disposition: form-data; name=\"";
				b.b += Std.string(this.file.param);
				b.b += "\"; filename=\"";
				b.b += Std.string(this.file.filename);
				b.b += "\"";
				b.b += "\r\n";
				b.b += Std.string("Content-Type: " + "application/octet-stream" + "\r\n" + "\r\n");
				uri = b.b;
			);
			else (;
				{ var $it2 : * = this.params.keys();
				while( $it2.hasNext() ) { var p : String = $it2.next();
				(;
					if(uri == null) uri = "";
					else uri += "&";
					uri += StringTools.urlEncode(p) + "=" + StringTools.urlEncode(this.params.get(p));
				);
				}}
			);
			let b : StringBuf = new StringBuf() in;
			if(method != null) (;
				b.b += Std.string(method);
				b.b += " ";
			);
			else if(post) b.b += "POST ";
			else b.b += "GET ";
			if(haxe.Http.PROXY != null) (;
				b.b += "http://";
				b.b += Std.string(host);
				if(port != 80) (;
					b.b += ":";
					b.b += Std.string(port);
				);
			);
			b.b += Std.string(request);
			if(!post && uri != null) (;
				if(request.indexOf("?",0) >= 0) b.b += "&";
				else b.b += "?";
				b.b += Std.string(uri);
			);
			b.b += Std.string(" HTTP/1.1\r\nHost: " + host + "\r\n");
			if(this.postData != null) b.b += Std.string("Content-Length: " + this.postData.length + "\r\n");
			else if(post && uri != null) (;
				if(multipart || this.headers.get("Content-Type") == null) (;
					b.b += "Content-Type: ";
					if(multipart) (;
						b.b += "multipart/form-data";
						b.b += "; boundary=";
						b.b += Std.string(boundary);
					);
					else b.b += "application/x-www-form-urlencoded";
					b.b += "\r\n";
				);
				if(multipart) b.b += Std.string("Content-Length: " + (uri.length + this.file.size + boundary.length + 6) + "\r\n");
				else b.b += Std.string("Content-Length: " + uri.length + "\r\n");
			);
			{ var $it3 : * = this.headers.keys();
			while( $it3.hasNext() ) { var h : String = $it3.next();
			(;
				b.b += Std.string(h);
				b.b += ": ";
				b.b += Std.string(this.headers.get(h));
				b.b += "\r\n";
			);
			}};
			b.b += "\r\n";
			if(this.postData != null) b.b += Std.string(this.postData);
			else if(post && uri != null) b.b += Std.string(uri);
			try (;
				if(haxe.Http.PROXY != null) sock.connect(new sys.net.Host(haxe.Http.PROXY.host),haxe.Http.PROXY.port);
				else sock.connect(new sys.net.Host(host),port);
				sock.write(b.b);
				if(multipart) (;
					let bufsize : int32 = 4096 in;
					let buf : haxe.io.Bytes = haxe.io.Bytes.alloc(bufsize) in;
					while(this.file.size > 0) (;
						let size : int32 = () in;
						if(this.file.size > bufsize) size = bufsize;
						else size = this.file.size;
						let len : int32 = 0 in;
						try (;
							len = this.file.io.readBytes(buf,0,size);
						);
						catch( e : haxe.io.Eof )(;
							break;
						);
						sock.output.writeFullBytes(buf,0,len);
						this.file.size -= len;
					);
					sock.write("\r\n");
					sock.write("--");
					sock.write(boundary);
					sock.write("--");
				);
				this.readHttpResponse(api,sock);
				sock.close();
			);
			catch( e : * )(;
				try (;
					sock.close();
				);
				catch( e1 : * )(;
				);
				this.onError(Std.string(e));
			);
		);
		
		public function request(post : * = null) : unit (;
			let me : haxe.Http = this in;
			let me1 : haxe.Http = this in;
			let output : haxe.io.BytesOutput = new haxe.io.BytesOutput() in;
			let old : String -> unit = this.onError in;
			let err : bool = false in;
			this.onError = function(e : String) : unit (;
				me1.responseData = output.getBytes().toString();
				err = true;
				old(e);
			);
			this.customRequest(post,output,null,null);
			if(!err) me1.onData(me1.responseData = output.getBytes().toString());
		);
		
		protected var params : haxe.ds.StringMap;
		protected var headers : haxe.ds.StringMap;
		protected var postData : String;
		protected var file : *;
		protected var chunk_buf : haxe.io.Bytes;
		protected var chunk_size : *;
		public var responseHeaders : haxe.ds.StringMap;
		public var cnxTimeout : float;
		public var noShutdown : bool;
		public var responseData : String;
		public var url : String;
		static public var PROXY : * = null;
		static public function requestUrl(url : String) : String (;
			let h : haxe.Http = new haxe.Http(url) in;
			let r : String = null in;
			h.onData = function(d : String) : unit (;
				r = d;
			);
			h.onError = function(e : String) : unit (;
				throw e;
			);
			h.request(false);
			return r;
		);
		
end;
	