package polymod.library;

import haxe.xml.Fast;
import haxe.xml.Printer;
import lime.utils.Assets;
#if sys
import sys.FileSystem;
#end
import lime.graphics.Image;
import lime.text.Font;
import lime.utils.Bytes;
import openfl.errors.Error;
#if unifill
import unifill.Unifill;
#end
#if (openfl >= "8.0.0")
import lime.utils.AssetLibrary;
import lime.media.AudioBuffer;
import lime.utils.AssetType;
#else
import lime.Assets.AssetLibrary;
import lime.audio.AudioBuffer;
import lime.Assets.AssetType;
#end

/**
 * 
 * @author 
 */
class ModAssetLibrary extends AssetLibrary
{
	/****VARS****/
	
	public var type(default, null) = new Map<String,AssetType>();
	
	private var dir:String;
	private var dirs:Array<String> = null;
	private var fallBackToDefault:Bool = true;
	private var fallback:AssetLibrary = null;
	
	/****PUBLIC****/
	
	/**
	 * Activating a mod is as simple as substituting the default asset library for this one!
	 * @param	Dir full path to the mod's root directory
	 * @param	FallBackToDefault if we can't find something, should we try the default asset library?
	 * @param	Dirs (optional) to combine mods, provide multiple paths to several mod's root directories. This takes precedence over the "Dir" parameter and the order matters -- mod files will load from first to last, with last taking precedence
	 */
	
	public function new(Dir:String, Fallback:AssetLibrary=null, Dirs:Array<String>=null)
	{
		dir = Dir;
		if (Dirs != null)
		{
			dirs = Dirs;
		}
		fallback = Fallback;
		super();
		fallBackToDefault = fallback != null;
		Sys.println("new ModAssetLibrary() Dir=" + Dir + " Dirs=" + Dirs);
		init();
	}
	
	public override function exists (id:String, type:String):Bool
	{
		var e = check(id);
		if (!e && fallBackToDefault)
		{
			return fallback.exists(id, type);
		}
		return e;
	}
	
	public override function getAudioBuffer (id:String):AudioBuffer
	{
		if (check(id))
		{
			return AudioBuffer.fromFile (file(id));
		}
		else if(fallBackToDefault)
		{
			return fallback.getAudioBuffer(id);
		}
		return null;
	}
	
	public override function getBytes (id:String):Bytes
	{
		if (check(id))
		{
			#if (openfl >= "8.0.0")
			return Bytes.fromFile (file(id));
			#else
			return Bytes.readFile (file(id));
			#end
		}
		else if (fallBackToDefault)
		{
			return fallback.getBytes(id);
		}
		return null;
	}
	
	/**
	 * Get text without consideration of any modifications
	 * @param	id
	 * @param	theDir
	 * @return
	 */
	public function getTextDirectly (id:String, directory:String = ""):String
	{
		var bytes = null;
		
		if (checkDirectly(directory,id))
		{
			#if (openfl >= "8.0.0")
			bytes = Bytes.fromFile (file(id, directory));
			#else
			bytes = Bytes.readFile (file(id, directory));
			#end
		}
		else if (fallBackToDefault)
		{
			bytes = fallback.getBytes(id);
		}
		
		if (bytes == null)
		{
			return null;
		} 
		else
		{
			return bytes.getString (0, bytes.length);
		}
		
		return null;
	}
	
	public override function getFont (id:String):Font
	{
		if (check(id))
		{
			return Font.fromFile (file(id));
		}
		else if (fallBackToDefault)
		{
			return fallback.getFont(id);
		}
		return null;
	}
	
	public override function getImage (id:String):Image
	{
		Sys.println("getImage(" + id + ")");
		if (check(id))
		{
			return Image.fromFile (file(id));
		}
		else if (fallBackToDefault)
		{
			return fallback.getImage(id);
		}
		return null;
	}
	
	
	public override function getPath (id:String):String
	{
		if (check(id))
		{
			return file(id);
		}
		else if (fallBackToDefault)
		{
			return fallback.getPath(id);
		}
		return null;
	}
	
	
	public override function getText (id:String):String
	{
		var modText = null;
		
		if (check(id))
		{
			modText = super.getText(id);
		}
		else if (fallBackToDefault)
		{
			modText = fallback.getText(id);
		}
		
		if (modText != null)
		{
			var theDirs = dirs != null ? dirs : [dir];
			modText = Util.mergeAndAppendText(modText, id, theDirs, getTextDirectly);
		}
		
		return modText;
	}
	
	
	public override function isLocal (id:String, type:String):Bool
	{
		if (check(id))
		{
			return true;
		}
		else if (fallBackToDefault)
		{
			return fallback.isLocal(id, type);
		}
		return false;
	}
	
	
	public override function list (type:String):Array<String>
	{
		Sys.println("list(" + type+")");
		
		var otherList = fallBackToDefault ? fallback.list(type) : [];
		
		Sys.println("fallback = " + fallback + " fallbacktodefault = " + fallBackToDefault);
		Sys.println("otherList = " + otherList);
		
		var requestedType = type != null ? cast (type, AssetType) : null;
		var items = [];
		
		for (id in this.type.keys ())
		{
			if (requestedType == null || exists (id, type))
			{
				items.push (id);
			}
		}
		
		for (otherId in otherList)
		{
			if (items.indexOf(otherId) == -1)
			{
				items.push(otherId);
			}
		}
		
		return items;
	}
	
	/****PRIVATE****/
	
	
	private function init():Void
	{
		#if sys
		type = new Map<String, AssetType>();
		if (dirs != null)
		{
			for (d in dirs)
			{
				_initMod(dir);
			}
		}
		else
		{
			_initMod(dir);
		}
		#end
	}
	
	private function _initMod(dir:String):Void
	{
		if (dir == null) return;
		
		Sys.println("_initMod(" + dir + ")");
		var all:Array<String> = null;
		
		if (dir == "" || dir == null)
		{
			all = [];
		}
		
		try
		{
			if (FileSystem.exists(dir))
			{
				all = Util.readDirectoryRecursive(dir);
				Sys.println("all = " + all);
			}
			else
			{
				all = [];
			}
		}
		catch (msg:Dynamic)
		{
			throw new Error("ModAssetLibrary._initMod(" + dir + ") failed : " + msg);
		}
		for (f in all)
		{
			if (f.indexOf("audio/music") == 0)
			{
				type.set(f, AssetType.MUSIC);
			}
			else if (f.indexOf("audio/sfx") == 0)
			{
				type.set(f, AssetType.SOUND);
			}
			else if (f.indexOf("fonts") == 0)
			{
				type.set(f, AssetType.FONT);
			}
			else
			{
				var doti = Util.uLastIndexOf(f,".");
				var ext:String = doti != -1 ? f.substring(doti) : "";
				switch(ext.toLowerCase())
				{
					case "mp3", "ogg", "wav": type.set(f, AssetType.SOUND);
					case "jpg", "png":type.set(f, AssetType.IMAGE);
					case "txt", "xml", "json", "tsv", "csv", "mpf", "tsx", "tmx", "vdf": type.set(f, AssetType.TEXT);
					case "ttf", "otf": type.set(f, AssetType.FONT);
					default: type.set(f, AssetType.BINARY);
				}
			}
		}
	}
	
	/**
	 * Check if the given asset exists
	 * (If using multiple mods, it will return true if ANY of the mod folders contains this file)
	 * @param	id
	 * @return
	 */
	private function check(id:String):Bool
	{
		#if sys
		id = Util.stripAssetsPrefix(id);
		if (dirs == null)
		{
			return FileSystem.exists(dir + Util.sl() + id);
		}
		else
		{
			for (d in dirs)
			{
				if (FileSystem.exists(d + Util.sl() + id))
				{
					return true;
				}
			}
		}
		#end
		return false;
	}
	
	private function checkDirectly(dir:String,id:String):Bool
	{
		#if sys
		id = Util.stripAssetsPrefix(id);
		if (dir == null || dir == "")
		{
			return FileSystem.exists(id);
		}
		else
		{
			var thePath = Util.uCombine([dir, Util.sl(), id]);
			if (FileSystem.exists(thePath))
			{
				return true;
			}
		}
		#end
		return false;
	}
	
	/**
	 * Get the filename of the given asset id
	 * (If using multiple mods, it will check all the mod folders for this file, and return the LAST one found)
	 * @param	id
	 * @return
	 */
	private function file(id:String, theDir:String = ""):String
	{
		id = Util.stripAssetsPrefix(id);
		
		if (theDir != "")
		{
			return theDir + Util.sl() + id;
		}
		else if (dirs == null)
		{
			return dir + Util.sl() + id;
		}
		else
		{
			var theFile = "";
			for (d in dirs)
			{
				var thePath = d + Util.sl() + id;
				if (FileSystem.exists(thePath))
				{
					theFile = thePath;
				}
			}
			return theFile;
		}
		return id;
	}
}