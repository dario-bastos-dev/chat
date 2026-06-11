import Rails from '@rails/ujs';
import '@hotwired/turbo-rails';
import '../portal/application.scss';
import { InitializationHelpers } from '../portal/portalHelpers';

Rails.start();

document.addEventListener('turbo:load', InitializationHelpers.onLoad);
