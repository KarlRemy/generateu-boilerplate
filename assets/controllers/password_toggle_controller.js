import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
    static targets = ['input', 'iconShow', 'iconHide'];

    connect() {
        // Find the password input within the controller scope if not explicitly targeted
        if (!this.hasInputTarget) {
            this._input = this.element.querySelector('input[type="password"]');
        }
    }

    toggle() {
        const input = this.hasInputTarget ? this.inputTarget : this._input;
        if (!input) return;

        const isPassword = input.type === 'password';
        input.type = isPassword ? 'text' : 'password';

        if (this.hasIconShowTarget && this.hasIconHideTarget) {
            this.iconShowTarget.classList.toggle('hidden', !isPassword);
            this.iconHideTarget.classList.toggle('hidden', isPassword);
        }
    }
}
