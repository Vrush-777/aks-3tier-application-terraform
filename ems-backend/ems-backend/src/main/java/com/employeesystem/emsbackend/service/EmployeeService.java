package com.employeesystem.emsbackend.service;

import com.employeesystem.emsbackend.entity.Employee;
import com.employeesystem.emsbackend.exception.ResourceNotFoundException;
import com.employeesystem.emsbackend.repository.EmployeeRepository;
import lombok.AllArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * EmployeeService provides business logic for employee management operations.
 * Includes structured logging and error handling.
 */
@Service
@AllArgsConstructor
public class EmployeeService {
    
    private static final Logger logger = LoggerFactory.getLogger(EmployeeService.class);
    private final EmployeeRepository employeeRepository;

    /**
     * Add a new employee to the database
     * @param employee Employee object to be saved
     * @return Saved employee with generated ID
     */
    public Employee addEmployee(Employee employee) {
        logger.info("Adding new employee with email: {}", employee.getEmail());
        try {
            Employee savedEmployee = employeeRepository.save(employee);
            logger.info("Employee successfully created with ID: {}", savedEmployee.getId());
            return savedEmployee;
        } catch (Exception e) {
            logger.error("Error adding employee with email: {}", employee.getEmail(), e);
            throw e;
        }
    }

    /**
     * Find an employee by ID
     * @param employeeId Employee ID
     * @return Employee object if found
     * @throws ResourceNotFoundException if employee not found
     */
    public Employee findEmployeeById(Long employeeId) {
        logger.debug("Fetching employee with ID: {}", employeeId);
        return employeeRepository.findById(employeeId)
                .orElseThrow(() -> {
                    logger.warn("Employee with ID {} not found", employeeId);
                    return new ResourceNotFoundException("Employee not found with ID: " + employeeId);
                });
    }

    /**
     * Get all employees from the database
     * @return List of all employees
     */
    public List<Employee> getAllEmployee() {
        logger.info("Fetching all employees");
        List<Employee> employees = employeeRepository.findAll();
        logger.info("Retrieved {} employees from database", employees.size());
        return employees;
    }

    /**
     * Update an existing employee
     * @param id Employee ID
     * @param updatedEmployee Updated employee data
     * @return Updated employee object
     * @throws ResourceNotFoundException if employee not found
     */
    public Employee updateEmployee(Long id, Employee updatedEmployee) {
        logger.info("Updating employee with ID: {}", id);
        try {
            Employee emp = findEmployeeById(id);
            emp.setFirstName(updatedEmployee.getFirstName());
            emp.setLastName(updatedEmployee.getLastName());
            emp.setEmail(updatedEmployee.getEmail());
            Employee savedEmployee = employeeRepository.save(emp);
            logger.info("Employee with ID: {} successfully updated", id);
            return savedEmployee;
        } catch (Exception e) {
            logger.error("Error updating employee with ID: {}", id, e);
            throw e;
        }
    }

    /**
     * Delete an employee by ID
     * @param id Employee ID
     * @throws ResourceNotFoundException if employee not found
     */
    public void deleteEmployeeById(Long id) {
        logger.info("Deleting employee with ID: {}", id);
        if (!employeeRepository.existsById(id)) {
            logger.warn("Cannot delete - employee not found with ID: {}", id);
            throw new ResourceNotFoundException("Employee not found with ID: " + id);
        }
        employeeRepository.deleteById(id);
        logger.info("Employee with ID: {} successfully deleted", id);
    }

    /**
     * Find employee by email address
     * @param email Employee email
     * @return Employee object if found
     */
    public Employee findEmployeeByEmail(String email) {
        logger.debug("Fetching employee with email: {}", email);
        Employee employee = employeeRepository.findByEmail(email);
        if (employee == null) {
            logger.warn("Employee not found with email: {}", email);
        }
        return employee;
    }
}
