//
//  CarouselCell.swift
//  InfiniScroll
//
//  Created by Michael Zuccarino on 5/20/16.
//  Copyright © 2016 asd. All rights reserved.
//

import UIKit

class CarouselCell: UIView {

    @IBOutlet weak var num:UILabel!

    class func createCarouselCell(parent parent:UIView, frame:CGRect) -> CarouselCell {
        let cell = UINib(nibName: "CarouselCell", bundle: nil).instantiateWithOwner(parent, options: nil)[0] as! CarouselCell
        cell.frame = frame
        cell.userInteractionEnabled = false
        return cell
    }
    
}
