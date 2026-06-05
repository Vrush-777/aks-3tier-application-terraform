package com.employeesystem.emsbackend.controller;

import com.employeesystem.emsbackend.entity.Employee;
import com.employeesystem.emsbackend.service.EmployeeService;
import lombok.AllArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * EmployeeController handles HTTP requests for employee management operations.
 * Exposes REST endpoints for CRUD operations.
 */
@CrossOrigin("*")
@RestController
@RequestMapping(path = "/api/emp")
@AllArgsConstructor
public class EmployeeController {
    
    private static final Logger logger = LoggerFactory.getLogger(EmployeeController.class);
    private final EmployeeService employeeService;

    /**
     * Create a new employee
     * @param employee Employee object from request body
     * @return Created employee with 201 status
     */
    @PostMapping
    public ResponseEntity<Employee> createEmployee(@RequestBody Employee employee) {
        logger.info("Request received to create employee with email: {}", employee.getEmail());
        Employee emp = employeeService.addEmployee(employee);
        logger.debug("Employee created successfully with ID: {}", emp.getId());
        return new ResponseEntity<>(emp, HttpStatus.CREATED);
    }

    /**
     * Find employee by ID
     * @param id Employee ID
     * @return Employee object if found
     */
    @GetMapping(path = "/{id}")
    public ResponseEntity<Employee> findEmployeeById(@PathVariable("id") Long id) {
        logger.info("Request received to find employee with ID: {}", id);
        Employee emp = employeeService.findEmployeeById(id);
        return ResponseEntity.ok(emp);
    }

    /**
     * Get all employees
     * @return List of all employees
     */
    @GetMapping
    public ResponseEntity<List<Employee>> getAllEmployee() {
        logger.info("Request received to retrieve all employees");
        List<Employee> e = employeeService.getAllEmployee();
        logger.debug("Retrieved {} employees", e.size());
        return ResponseEntity.ok(e);
    }

    /**
     * Update an existing employee
     * @param id Employee ID
     * @param updateEmployee Updated employee data
     * @return Updated employee object
     */
    @PutMapping("{id}")
    public ResponseEntity<Employee> updateEmployee(@PathVariable("id") Long id,
                                                   @RequestBody Employee updateEmployee) {
        logger.info("Request received to update employee with ID: {}", id);
        Employee emp = employeeService.updateEmployee(id, updateEmployee);
        logger.debug("Employee with ID: {} successfully updated", id);
        return ResponseEntity.ok(emp);
    }

    /**
     * Delete an employee by ID
     * @param id Employee ID
     * @return Success message
     */
    @DeleteMapping("{id}")
    public ResponseEntity<String> deleteById(@PathVariable("id") Long id) {
        logger.info("Request received to delete employee with ID: {}", id);
        employeeService.deleteEmployeeById(id);
        logger.debug("Employee with ID: {} successfully deleted", id);
        return ResponseEntity.ok("Employee Deleted Successfully");
    }

    /**
     * Find employee by email address
     * @param email Employee email
     * @return Employee object if found
     */
    @GetMapping("/email-id/{mail}")
    public ResponseEntity<Employee> findByEmployeeEmail(@PathVariable("mail") String email) {
        logger.info("Request received to find employee with email: {}", email);
        Employee emp = employeeService.findEmployeeByEmail(email);
        return ResponseEntity.ok(emp);
    }
}
