# audit-aws-instances
Audits AWS instances for unused reserved instances, or instances without corresponding reserved instances.  Designed for use as a sensu/nagios plugin, so no output is good.  



## Return
Returns exit code 1 (warn) if there are any outstanding RIs or unreserved instances.  
Returns exit code 2 (crit) if there are >$crit outstanding for any instance type.


## Sample output
```
UNRESERVED INSTANCES: (4) - m3.large
UNRESERVED INSTANCES: (2) - m3.xlarge
UNUSED RESERVATION: (1) - m3.2xlarge
UNUSED RESERVATION: (1) - m4.large
UNUSED RESERVATION: (1) - r3.large
UNRESERVED INSTANCES: (1) - r3.2xlarge
```

## Output
UNUSED RESERVATION : there are no instance for this instance type.
UNRESERVED INSTANCES : the number of RI is smaller than the number of active instances of this type.


# Configuration
Install and configure the AWS CLI and give the IAM user the necessary permissions to check reservations.

http://docs.aws.amazon.com/AWSEC2/latest/CommandLineReference/set-up-ec2-cli-linux.html

Make sure "aws cli" runs without errors, and the script should work.  


This version of the script queries the list of aws regions. 


## todo :
. we are only checking for EC2 instances of types that do exist in the RI list (since we get the instances types from the RI list == change this.

