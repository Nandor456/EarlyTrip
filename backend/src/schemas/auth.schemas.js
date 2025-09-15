import { z } from "zod";
import { parsePhoneNumberFromString } from "libphonenumber-js";

export const registrationSchema = z.object({
  firstName: z.string().min(3, "firstname must be at least 3 characters long"),
  lastName: z.string().min(3, "lastname must be at least 3 characters long"),
  password: z.string().min(6, "Password must be at least 6 characters long"),
  email: z.email("Invalid email address"),
  phone: z.string().refine(
    (val) => {
      const phoneNumber = parsePhoneNumberFromString(val, "RO");
      return phoneNumber ? phoneNumber.isValid() : false;
    },
    {
      message: "Invalid phone number",
    }
  ),
});
