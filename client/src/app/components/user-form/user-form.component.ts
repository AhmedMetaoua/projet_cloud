import {Component, EventEmitter, Input, OnChanges, Output, SimpleChanges} from '@angular/core';
import {FormBuilder, FormGroup, Validators} from '@angular/forms';
import {User, UserService} from '../../services/user.service';

@Component({
  selector: 'app-user-form',
  standalone: false,
  templateUrl: './user-form.component.html',
  styleUrl: './user-form.component.css'
})
export class UserFormComponent implements OnChanges {

  @Input() userToEdit: User | null = null;
  @Output() userSaved = new EventEmitter<void>();
  @Output() cancelEdit = new EventEmitter<void>();

  userForm: FormGroup;
  submitting = false;
  success = false;
  error: string | null = null;
  isEditMode = false;

  constructor(
    private fb: FormBuilder,
    private userService: UserService
  ) {
    this.userForm = this.createForm();
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['userToEdit'] && changes['userToEdit'].currentValue) {
      this.isEditMode = true;
      const user = changes['userToEdit'].currentValue;
      this.userForm.patchValue({
        id: user.id,
        name: user.name,
        email: user.email
      });
    }
  }

  createForm(): FormGroup {
    return this.fb.group({
      id: [null],
      name: ['', [Validators.required]],
      email: ['', [Validators.required, Validators.email]]
    });
  }

  onSubmit(): void {
    if (this.userForm.invalid) {
      return;
    }

    this.submitting = true;
    this.success = false;
    this.error = null;

    const user: User = this.userForm.value;

    const request = this.isEditMode
      ? this.userService.updateUser(user)
      : this.userService.addUser(user);

    request.subscribe({
      next: (response) => {
        console.log(this.isEditMode ? 'User updated successfully:' : 'User added successfully:', response);
        this.submitting = false;
        this.success = true;

        if (this.isEditMode) {
          this.userSaved.emit();
          this.resetForm();
        } else {
          this.userForm.reset();

          // Reset success message after 3 seconds
          setTimeout(() => {
            this.success = false;
          }, 3000);
        }
      },
      error: (err) => {
        console.error(this.isEditMode ? 'Error updating user:' : 'Error adding user:', err);
        this.submitting = false;
        this.error = this.isEditMode
          ? 'Failed to update user. Please try again.'
          : 'Failed to add user. Please try again.';
      }
    });
  }

  resetForm(): void {
    this.isEditMode = false;
    this.userToEdit = null;
    this.userForm.reset();
    this.cancelEdit.emit();
  }
}
