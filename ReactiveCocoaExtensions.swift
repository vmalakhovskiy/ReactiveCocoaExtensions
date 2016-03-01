//
//  ReactiveCocoaExtensions.swift
//  QuickTrack
//
//  Created by Vitaliy Malakhovskiy on 11/18/15.
//  Copyright © 2015 Vitalii Malakhovskyi. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result

struct AssociationKey {
    static var hidden: UInt8 = 1
    static var alpha: UInt8 = 2
    static var text: UInt8 = 3
    static var enabled: UInt8 = 4
    static var action: UInt8 = 5
    static var image: UInt8 = 6
    static var textColor: UInt8 = 7
    static var active: UInt8 = 8
    static var date: UInt8 = 9
    static var sliderValue: UInt8 = 10
    static var actionKey: UInt8 = 11
    static var enabledKey: UInt8 = 12
    static var attributedText: UInt8 = 13
}

extension NSObject {
    func rac_willDeallocSignalProducer() -> SignalProducer<(), NoError> {
        return rac_willDeallocSignal().toSignalProducer()
            .map { _ in () }
            .flatMapError { _ in SignalProducer<(), NoError>.empty  }
    }
}

extension UIViewController {
    func rac_viewWillDissappear() -> SignalProducer<(), NoError> {
        return self.rac_signalForSelector(Selector("viewWillDisappear:"))
            .toSignalProducer()
            .map { _ in () }
            .flatMapError { _ in SignalProducer<(), NoError>.empty  }
    }
    
    func rac_willShowKeyboard() -> SignalProducer<NSNotification?, NoError> {
        return NSNotificationCenter.defaultCenter()
                .rac_addObserverForName(UIKeyboardWillShowNotification, object: nil)
                .toSignalProducer()
                .map { $0 as? NSNotification }
                .flatMapError { _ -> SignalProducer<NSNotification?, NoError> in
                    return SignalProducer.empty
        }
    }
    
    func rac_willHideKeyboard() -> SignalProducer<NSNotification?, NoError> {
        return NSNotificationCenter.defaultCenter()
            .rac_addObserverForName(UIKeyboardWillHideNotification, object: nil)
            .toSignalProducer()
            .map { $0 as? NSNotification }
            .flatMapError { _ -> SignalProducer<NSNotification?, NoError> in
                return SignalProducer.empty
        }
    }
}

// lazily creates a gettable associated property via the given factory
func lazyAssociatedProperty<T: AnyObject>(host: AnyObject, key: UnsafePointer<Void>, factory: () -> T) -> T {
    return objc_getAssociatedObject(host, key) as? T ?? {
        let associatedProperty = factory()
        objc_setAssociatedObject(host, key, associatedProperty, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        return associatedProperty
        }()
}

func lazyMutableProperty<T>(host: AnyObject, key: UnsafePointer<Void>, setter: T -> (), getter: () -> T) -> MutableProperty<T> {
    return lazyAssociatedProperty(host, key: key) {
        let property = MutableProperty<T>(getter())
        property.producer.startWithNext { newValue in
            setter(newValue)
        }
        return property
    }
}

extension UIView {
    public var rac_alpha: MutableProperty<CGFloat> {
        return lazyMutableProperty(self, key: &AssociationKey.alpha, setter: { self.alpha = $0 }, getter: { self.alpha  })
    }
    
    public var rac_hidden: MutableProperty<Bool> {
        return lazyMutableProperty(self, key: &AssociationKey.hidden, setter: { self.hidden = $0 }, getter: { self.hidden  })
    }
}

extension UISearchBar: UISearchBarDelegate {
    public var rac_text: MutableProperty<String> {
        return lazyAssociatedProperty(self, key: &AssociationKey.text) {

            self.delegate = self
            self.rac_signalForSelector(Selector("searchBar:textDidChange:"), fromProtocol: UISearchBarDelegate.self)
                .toSignalProducer()
                .startWithNext({ [weak self] _ in
                    self?.changed()
                    
                    })
            
            let property = MutableProperty<String>(self.text ?? "")
            property.producer.startWithNext { newValue in
                self.text = newValue
            }
            return property
        }
    }
    
    func changed() {
        rac_text.value = self.text ?? ""
    }
}

extension UIBarItem {
    /// Wraps a UIBarItem's `enabled` state in a bindable property.
    public var rex_enabled: MutableProperty<Bool> {
        return lazyMutableProperty(self, key: &AssociationKey.enabledKey, setter: { self.enabled = $0 }, getter: { self.enabled })
    }
}

extension UISlider {
    public var rac_value: MutableProperty<Float> {
        return lazyAssociatedProperty(self, key: &AssociationKey.sliderValue) {

            self.addTarget(self, action: "changed", forControlEvents: UIControlEvents.ValueChanged)
            
            let property = MutableProperty<Float>(self.value)
            property.producer.startWithNext { newValue in
                self.setValue(newValue, animated: true)
            }
            return property
        }
    }
    
    func changed() {
        rac_value.value = self.value
    }
}

extension UIDatePicker {
    public var rac_date: MutableProperty<NSDate> {
        return lazyAssociatedProperty(self, key: &AssociationKey.date) {
            
            self.addTarget(self, action: "changed", forControlEvents: UIControlEvents.ValueChanged)
            
            let property = MutableProperty<NSDate>(self.date)
            property.producer.startWithNext { newValue in
                self.setDate(newValue, animated: true)
            }
            return property
        }
    }
    
    func changed() {
        rac_date.value = self.date
    }
}

extension UILabel {
    public var rac_text: MutableProperty<String> {
        return lazyMutableProperty(self, key: &AssociationKey.text, setter: { self.text = $0 }, getter: { self.text ?? "" })
    }
    
    public var rac_attributedText: MutableProperty<NSAttributedString> {
        return lazyMutableProperty(self, key: &AssociationKey.attributedText, setter: { self.attributedText = $0 }, getter: { self.attributedText ?? NSAttributedString() })
    }
    
    public var rac_textColor: MutableProperty<UIColor> {
        return lazyMutableProperty(self, key: &AssociationKey.textColor, setter: { self.textColor = $0 }, getter: { self.textColor })
    }
}

extension UIImageView {
    public var rac_image: MutableProperty<UIImage> {
        return lazyMutableProperty(self, key: &AssociationKey.image, setter: { self.image = $0 }, getter: { self.image ?? UIImage() })
    }
}

extension UIControl {
    public var rac_enabled: MutableProperty<Bool> {
        return lazyMutableProperty(self, key: &AssociationKey.enabled, setter: { self.enabled = $0 }, getter: { self.enabled })
    }
}

extension UITextField {
    public var rac_text: MutableProperty<String> {
        return lazyAssociatedProperty(self, key: &AssociationKey.text) {
            
            self.addTarget(self, action: "changed", forControlEvents: UIControlEvents.EditingChanged)
            
            let property = MutableProperty<String>(self.text ?? "")
            property.producer.startWithNext { newValue in
                self.text = newValue
            }
            return property
        }
    }
    
    func changed() {
        rac_text.value = self.text ?? ""
    }
}

extension UITableViewCell {
    var rac_prepareForReuseSignalProducer: SignalProducer<Void, NoError> {
        return rac_prepareForReuseSignal
            .toSignalProducer()
            .flatMapError({ _ in return SignalProducer<AnyObject?, NoError>.empty })
            .map({ _ in })
    }
}