/**
 * Extracts coordinates from what an agent has at hand on the desktop: a Google Maps URL copied
 * from the address bar, a coordinate pair copied from the map's right-click menu, or a link from
 * another maps service.
 */

// A place URL carries the map centre in `@lat,lng,zoom` and the place itself in the `!3d!4d`
// data blob. The data blob wins, because the centre drifts as the agent pans the map.
const PLACE_DATA = /!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/;
const MAP_CENTRE = /@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/;
// maps.google.com/?q=, the Maps URL API, Apple Maps and Waze all pass the pair in a query param.
const QUERY_PAIR =
  /[?&](?:q|query|ll|sll|center|daddr|destination)=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/;
// OpenStreetMap splits it across two params.
const OSM_LAT = /[?&]mlat=(-?\d+(?:\.\d+)?)/;
const OSM_LON = /[?&]mlon=(-?\d+(?:\.\d+)?)/;
// Right-clicking a point in Google Maps copies exactly this.
const RAW_PAIR = /^\s*(-?\d+(?:\.\d+)?)\s*[,;]\s*(-?\d+(?:\.\d+)?)\s*$/;

const PLACE_NAME = /\/maps\/place\/([^/@?]+)/;

/**
 * A shortened link resolves to the real URL only by following its redirect, which the browser
 * cannot read. Callers use this to tell the agent what to do instead of just rejecting the input.
 */
export const isShortMapLink = value =>
  /^https?:\/\/(?:maps\.app\.goo\.gl|goo\.gl\/maps)\//i.test(value.trim());

const safeDecode = value => {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
};

const toCoordinates = (rawLatitude, rawLongitude) => {
  const latitude = Number(rawLatitude);
  const longitude = Number(rawLongitude);

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null;

  return { latitude, longitude };
};

// Google puts the place segment of the URL to two uses: the business name when the agent searched
// for a place, and the whole formatted address when they searched for an address. Only the second
// carries a house number and the commas separating the parts of the address.
const looksLikeAddress = place => /\d/.test(place) && place.includes(',');

// The segment is worth one field or the other, never both, so returning it under the right key
// lets the caller fill the form without guessing again.
const extractPlace = value => {
  const match = value.match(PLACE_NAME);
  if (!match) return {};

  const place = safeDecode(match[1].replace(/\+/g, ' ')).trim();
  // Google falls back to the coordinates as the place segment when the point has no name.
  if (!place || RAW_PAIR.test(place)) return {};

  return looksLikeAddress(place) ? { address: place } : { name: place };
};

/**
 * @param {string} value - a maps URL or a coordinate pair
 * @returns {{latitude: number, longitude: number, name?: string, address?: string} | null}
 */
export const parseMapLocation = value => {
  const input = safeDecode((value || '').trim());
  if (!input) return null;

  const osmLatitude = input.match(OSM_LAT);
  const osmLongitude = input.match(OSM_LON);

  const match =
    input.match(PLACE_DATA) ||
    input.match(MAP_CENTRE) ||
    input.match(QUERY_PAIR) ||
    input.match(RAW_PAIR) ||
    (osmLatitude && osmLongitude
      ? [null, osmLatitude[1], osmLongitude[1]]
      : null);

  if (!match) return null;

  const coordinates = toCoordinates(match[1], match[2]);
  if (!coordinates) return null;

  return { ...coordinates, ...extractPlace(input) };
};
