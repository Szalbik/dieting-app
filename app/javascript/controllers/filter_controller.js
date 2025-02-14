import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"  
  
export default class extends Controller {  
  static targets = [ "checkbox" ]  
  
  connect() {  
    console.log("Connected to SubmitFormController!")  
  }  

  submitForm(event) {  
    this.element.submit()  
  }  

  filter() {  
    const checkedBoxes = this.checkboxTargets.filter(checkbox => checkbox.checked)  
    const checkedValues = checkedBoxes.map(checkbox => checkbox.value)  

    console.log('Values: ', checkedValues)

    // Trigger a Turbo Frame request  
    // Turbo.visit(`/products?day=${checkedValues.join(',')}`, { action: 'replace', target: 'products' })  
  }  
}  
