use accessibility::{AXUIElement, AXUIElementAttributes};
use core_foundation::{array::{CFArrayGetCount, CFArrayGetValueAtIndex}, dictionary::CFDictionaryGetKeysAndValues};
use core_graphics::{display::{CFDictionary, CFDictionaryRef, CGWindowListCopyWindowInfo}, window::{kCGNullWindowID, kCGWindowName}};
use core_graphics::display::kCGWindowListExcludeDesktopElements;
use objc::{msg_send, sel, sel_impl};

use cocoa::{
    appkit::{NSApp, NSApplication, NSApplicationActivationPolicy::*},
    base::{id, nil, BOOL, NO, YES},
    foundation::{NSDictionary, NSPoint, NSSize, NSString},
};

struct AbletonInstance {
    pid: i32,
}

impl AbletonInstance {
    fn new(pid: i32) -> Self {
        Self {
            pid,
        }
    }
    
    fn get_app(&self) -> AXUIElement {
        let app = AXUIElement::application(self.pid);
        app.action_names();
        app.attribute_names();
        app.children();
        app.description();
        app.title();
        return app;
    }
}

struct InstanceManager {
    instances: Vec<AbletonInstance>
}

impl InstanceManager {
    fn new() -> Self {
        Self {
            instances: Vec::new()
        }
        
    }

    fn get_window_list(&self) {
      unsafe {
        let window_list = CGWindowListCopyWindowInfo(kCGWindowListExcludeDesktopElements, kCGNullWindowID);
        let size = CFArrayGetCount(window_list);
        println!("size: {}", size);
        for i in 0..size {
          let w: CFDictionaryRef = CFArrayGetValueAtIndex(window_list, i) as _; // CFDictionary
          let keys = std::ptr::null_mut();
          let values = std::ptr::null_mut();
          CFDictionaryGetKeysAndValues(w, keys, values);
          // print all the keys and values
          for i in 0..CFDictionaryGetCount(w) {
            let key = CFArrayGetValueAtIndex(keys, i) as CFString;
            let value = CFArrayGetValueAtIndex(values, i) as CFString;
            println!("{}: {}", key, value);
          }

          
        }
      }
    }
}



fn main() {
    // guys i don't know rust why did i think this was a good idea
    let manager = InstanceManager::new();
    manager.get_window_list();
    // let ableton = AbletonInstance::new(37611);
    // let app = ableton.get_app();
    // app.children()
}

