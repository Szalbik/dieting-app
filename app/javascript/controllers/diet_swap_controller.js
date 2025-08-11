import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["datePicker", "swapButton"]
  static values = { 
    currentDate: String,
    isSwapMode: Boolean
  }

  connect() {
    this.isSwapModeValue = false
    // Get current date from URL parameters or find the selected date in the date picker
    this.currentDateValue = this.getCurrentDate()
  }

  getCurrentDate() {
    // First try to get from the data attribute
    if (this.element.dataset.currentDate) {
      return this.element.dataset.currentDate
    }
    
    // If not available, try to get from URL parameters
    const urlParams = new URLSearchParams(window.location.search)
    const dateParam = urlParams.get('date')
    if (dateParam) {
      return dateParam
    }
    
    // If still not available, find the selected date in the date picker
    const selectedDateLink = this.datePickerTarget.querySelector('a[aria-current="date"]')
    if (selectedDateLink) {
      const dateMatch = selectedDateLink.href.match(/date=([^&]+)/)
      if (dateMatch) {
        return dateMatch[1]
      }
    }
    
    // Fallback to today's date
    const today = new Date()
    const todayString = today.toISOString().split('T')[0]
    return todayString
  }

  toggleSwapMode() {
    this.isSwapModeValue = !this.isSwapModeValue
    
    if (this.isSwapModeValue) {
      this.enterSwapMode()
    } else {
      this.exitSwapMode()
    }
  }

  enterSwapMode() {
    
    // Ensure we have a valid current date
    if (!this.currentDateValue) {
      this.currentDateValue = this.getCurrentDate()
    }
    
    // Add swap mode styling to the button
    this.swapButtonTarget.classList.add('bg-red-100', 'text-red-700', 'border-red-300')
    this.swapButtonTarget.classList.remove('text-gray-400')
    this.swapButtonTarget.textContent = 'Anuluj zamianę'
    
    // Make all dates blink except current one
    const dateLinks = this.datePickerTarget.querySelectorAll('a')
    
    dateLinks.forEach((dateLink, index) => {
      const dateValue = dateLink.href.match(/date=([^&]+)/)?.[1]
      
      if (dateValue && dateValue !== this.currentDateValue) {
        dateLink.classList.add('animate-pulse', 'ring-2', 'ring-red-400', 'ring-opacity-50')
        dateLink.dataset.swapMode = 'true'
        
        // Also add some visual feedback to make it more obvious
        dateLink.style.borderColor = '#f87171' // red-400
        dateLink.style.borderWidth = '3px'
      } else {
      }
    })
  }

  exitSwapMode() {
    // Remove swap mode styling from button
    this.swapButtonTarget.classList.remove('bg-red-100', 'text-red-700', 'border-red-300')
    this.swapButtonTarget.classList.add('text-gray-400')
    this.swapButtonTarget.textContent = 'Zamień zestaw diety'
    
    // Remove blinking from all dates
    this.datePickerTarget.querySelectorAll('a[data-swap-mode="true"]').forEach(dateLink => {
      dateLink.classList.remove('animate-pulse', 'ring-2', 'ring-red-400', 'ring-opacity-50')
      dateLink.style.borderColor = '' // Reset to default
      dateLink.style.borderWidth = '' // Reset to default
      delete dateLink.dataset.swapMode
    })
  }

  async swapDietSets(event) {
    if (!this.isSwapModeValue) {
      return
    }
    
    event.preventDefault()
    
    const targetDate = event.currentTarget.href.match(/date=([^&]+)/)?.[1]
    
    if (!targetDate || targetDate === this.currentDateValue) {
      return
    }
    
    if (confirm(`Czy na pewno chcesz zamienić zestawy diety między ${this.currentDateValue} a ${targetDate}?`)) {
      try {
        const response = await fetch('/diet_set_plans/swap', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
          },
          body: JSON.stringify({
            current_date: this.currentDateValue,
            target_date: targetDate
          })
        })
        
        
        if (response.ok) {
          const result = await response.json()
          // Refresh the page to show the swapped diet sets
          window.location.reload()
        } else {
          const errorResult = await response.json()
          console.error('Swap failed:', errorResult)
          alert('Wystąpił błąd podczas zamiany zestawów diety.')
        }
      } catch (error) {
        console.error('Error swapping diet sets:', error)
        alert('Wystąpił błąd podczas zamiany zestawów diety.')
      }
    } else {
    }
    
    // Exit swap mode after swap attempt
    this.exitSwapMode()
  }
}
