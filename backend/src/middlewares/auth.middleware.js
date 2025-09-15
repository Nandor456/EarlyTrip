import { registrationSchema } from "../schemas/auth.schemas.js";
import { UserEmailExists, UserPhoneExists } from "../services/auth.service.js";
import { userExists } from "../services/auth.service.js";

export const validateRegistration = async (req, res, next) => {
  const { firstName, lastName, password, email, phone } = req.body;
  console.log("Validating registration data:", req.body);
  const emailExists = await UserEmailExists(email);
  if (emailExists) {
    console.log("Email already exists:", email);
    return res.status(400).json({ message: "Email already exists" });
  }
  const phoneExists = await UserPhoneExists(phone);
  if (phoneExists) {
    console.log("Phone number already exists:", phone);
    return res.status(400).json({ message: "Phone number already exists" });
  }
  const result = registrationSchema.safeParse({
    firstName,
    lastName,
    password,
    email,
    phone,
  });

  if (!result.success) {
    const error = result.error.issues.map((issue) => issue.message).join("\n");

    return res.status(400).json({
      message: error,
    });
  }

  console.log("Validation passed successfully!");
  next();
};

export function validateLogin(req, res, next) {
  const { email, password } = req.body;
  console.log("Validating login data:", req.body);
  if (!email || !password) {
    console.log("Missing email or password");
    return res.status(400).json({ message: "Email and password are required" });
  }
  const result = userExists(email, password);
  if (!result.success) {
    console.log(result.message);
    return res.status(401).json({ message: result.message });
  }
  console.log("Login validation passed successfully!");
  next();
}
