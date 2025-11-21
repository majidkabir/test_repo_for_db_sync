SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION dbo.fnc_Code128C_Uni
(
@Barcode VARCHAR(255)
)
RETURNS VARCHAR(255)
BEGIN

   DECLARE
      @v_full_data_to_encode NVARCHAR(255) 
     ,@v_printable_string    NVARCHAR(255) 
     ,@v_weighted_total      BIGINT
     ,@v_length              INT 
     ,@v_current_value       INT
     ,@v_check_digit_value   INT
     ,@v_return              NVARCHAR(255)
     ,@v_temp                NCHAR --in case we need to add a zero
     ,@v_weight_value        INT
     ,@v_correct_data        NVARCHAR(255)
     ,@v_value               INT   
     ,@v_convcode            NVARCHAR(3)
     ,@v_i                   INT

   SET @v_full_data_to_encode = @Barcode
   SET @v_printable_string = ''
   SET @v_correct_data = ''
   SET @v_temp = '0'
   
   SET @v_weighted_total = 105	--Weighted total for check digit calculation. initialize with set C start character
   SET @v_weight_value = 1
   SET @v_length = 0
   SET @v_i = 1
   
   SET @v_length = LEN(@v_full_data_to_encode)
   
   --Check to make sure data is numeric and remove dashes, etc.
   WHILE @v_i <= @v_length
   BEGIN
      /* Add all numbers to OnlyCorrectData string */
      IF (ASCII(SUBSTRING(@v_full_data_to_encode,@v_i,1)) >= 48) 
          AND (ASCII(SUBSTRING(@v_full_data_to_encode,@v_i,1)) <= 57) 
      BEGIN			     
          SET @v_correct_data = RTRIM(@v_correct_data) + SUBSTRING(@v_full_data_to_encode,@v_i,1) 
      END 
   	
   	  SET @v_i = @v_i + 1
   END
   
   SET @v_length = LEN(@v_correct_data)
   	
   IF (@v_length % 2) <> 0
   BEGIN		
      SET @v_correct_data = @v_temp + @v_correct_data 		
   END 
       
   SET @v_length = LEN(@v_correct_data)
   SET @v_i = 1
   
   WHILE @v_i < @v_length
   BEGIN
   	 SET @v_current_value = CONVERT(INT, SUBSTRING(@v_correct_data, @v_i,2))
   	 
   	 SET @v_value = @v_current_value + 1
   
     SELECT @v_convcode = CASE @v_value WHEN 1 THEN 'EFF' WHEN 2 THEN 'FEF' WHEN 3 THEN 'FFE' WHEN 4 THEN 'BBG' WHEN 5 THEN 'BCF'
                                        WHEN 6 THEN 'CBF' WHEN 7 THEN 'BFC' WHEN 8 THEN 'BGB' WHEN 9 THEN 'CFB' WHEN 10 THEN 'FBC'
                                        WHEN 11 THEN 'FCB' WHEN 12 THEN 'GBB' WHEN 13 THEN 'AFJ' WHEN 14 THEN 'BEJ' WHEN 15 THEN 'BFI'
                                        WHEN 16 THEN 'AJF' WHEN 17 THEN 'BIF' WHEN 18 THEN 'BJE' WHEN 19 THEN 'FJA' WHEN 20 THEN 'FAJ'
                                        WHEN 21 THEN 'FBI' WHEN 22 THEN 'EJB' WHEN 23 THEN 'FIB' WHEN 24 THEN 'IEI' WHEN 25 THEN 'IBF'
                                        WHEN 26 THEN 'JAF' WHEN 27 THEN 'JBE' WHEN 28 THEN 'IFB' WHEN 29 THEN 'JEB' WHEN 30 THEN 'JFA'
                                        WHEN 31 THEN 'EEG' WHEN 32 THEN 'EGE' WHEN 33 THEN 'GEE' WHEN 34 THEN 'ACG' WHEN 35 THEN 'CAG' 
                                        WHEN 36 THEN 'CCE' WHEN 37 THEN 'AGC' WHEN 38 THEN 'CEC' WHEN 39 THEN 'CGA' WHEN 40 THEN 'ECC'
                                        WHEN 41 THEN 'GAC' WHEN 42 THEN 'GCA' WHEN 43 THEN 'AEK' WHEN 44 THEN 'AGI' WHEN 45 THEN 'CEI' 
                                        WHEN 46 THEN 'AIG' WHEN 47 THEN 'AKE' WHEN 48 THEN 'CIE' WHEN 49 THEN 'IIE' WHEN 50 THEN 'ECI'
                                        WHEN 51 THEN 'GAI' WHEN 52 THEN 'EIC' WHEN 53 THEN 'EKA' WHEN 54 THEN 'EII' WHEN 55 THEN 'IAG' 
                                        WHEN 56 THEN 'ICE' WHEN 57 THEN 'KAE' WHEN 58 THEN 'IEC' WHEN 59 THEN 'IGA' WHEN 60 THEN 'KEA'
                                        WHEN 61 THEN 'IMA' WHEN 62 THEN 'FDA' WHEN 63 THEN 'OAA' WHEN 64 THEN 'ABH' WHEN 65 THEN 'ADF' 
                                        WHEN 66 THEN 'BAH' WHEN 67 THEN 'BDE' WHEN 68 THEN 'DAF' WHEN 69 THEN 'DBE' WHEN 70 THEN 'AFD'
                                        WHEN 71 THEN 'AHB' WHEN 72 THEN 'BED' WHEN 73 THEN 'BHA' WHEN 74 THEN 'DEB' WHEN 75 THEN 'DFA' 
                                        WHEN 76 THEN 'HBA' WHEN 77 THEN 'FAD' WHEN 78 THEN 'MIA' WHEN 79 THEN 'HAB' WHEN 80 THEN 'CMA'
                                        WHEN 81 THEN 'ABN' WHEN 82 THEN 'BAN' WHEN 83 THEN 'BBM' WHEN 84 THEN 'ANB' WHEN 85 THEN 'BMB' 
                                        WHEN 86 THEN 'BNA' WHEN 87 THEN 'MBB' WHEN 88 THEN 'NAB' WHEN 89 THEN 'NBA' WHEN 90 THEN 'EEM'
                                        WHEN 91 THEN 'EME' WHEN 92 THEN 'MEE' WHEN 93 THEN 'AAO' WHEN 94 THEN 'ACM' WHEN 95 THEN 'CAM' 
                                        WHEN 96 THEN 'AMC' WHEN 97 THEN 'AOA' WHEN 98 THEN 'MAC' WHEN 99 THEN 'MCA' WHEN 100 THEN 'AIM'
                                        WHEN 101 THEN 'AMI' WHEN 102 THEN 'IAM' WHEN 103 THEN 'MAI' WHEN 104 THEN 'EDB' WHEN 105 THEN 'EBD' 
                                        WHEN 106 THEN 'EBJ' END

   	    					
   	 SET @v_printable_string = RTRIM(@v_printable_string) + @v_convcode
   	 SET @v_weighted_total = @v_weighted_total + ((@v_current_value) * @v_weight_value)
   	 SET @v_weight_value = @v_weight_value + 1
   	 SET @v_i = @v_i + 2
   END
   		
   SET @v_check_digit_value = @v_weighted_total % 103
   
   SET @v_value = @v_check_digit_value + 1
   
   SELECT @v_convcode = CASE @v_value WHEN 1 THEN 'EFF' WHEN 2 THEN 'FEF' WHEN 3 THEN 'FFE' WHEN 4 THEN 'BBG' WHEN 5 THEN 'BCF'
                                      WHEN 6 THEN 'CBF' WHEN 7 THEN 'BFC' WHEN 8 THEN 'BGB' WHEN 9 THEN 'CFB' WHEN 10 THEN 'FBC'
                                      WHEN 11 THEN 'FCB' WHEN 12 THEN 'GBB' WHEN 13 THEN 'AFJ' WHEN 14 THEN 'BEJ' WHEN 15 THEN 'BFI'
                                      WHEN 16 THEN 'AJF' WHEN 17 THEN 'BIF' WHEN 18 THEN 'BJE' WHEN 19 THEN 'FJA' WHEN 20 THEN 'FAJ'
                                      WHEN 21 THEN 'FBI' WHEN 22 THEN 'EJB' WHEN 23 THEN 'FIB' WHEN 24 THEN 'IEI' WHEN 25 THEN 'IBF'
                                      WHEN 26 THEN 'JAF' WHEN 27 THEN 'JBE' WHEN 28 THEN 'IFB' WHEN 29 THEN 'JEB' WHEN 30 THEN 'JFA'
                                      WHEN 31 THEN 'EEG' WHEN 32 THEN 'EGE' WHEN 33 THEN 'GEE' WHEN 34 THEN 'ACG' WHEN 35 THEN 'CAG' 
                                      WHEN 36 THEN 'CCE' WHEN 37 THEN 'AGC' WHEN 38 THEN 'CEC' WHEN 39 THEN 'CGA' WHEN 40 THEN 'ECC'
                                      WHEN 41 THEN 'GAC' WHEN 42 THEN 'GCA' WHEN 43 THEN 'AEK' WHEN 44 THEN 'AGI' WHEN 45 THEN 'CEI' 
                                      WHEN 46 THEN 'AIG' WHEN 47 THEN 'AKE' WHEN 48 THEN 'CIE' WHEN 49 THEN 'IIE' WHEN 50 THEN 'ECI'
                                      WHEN 51 THEN 'GAI' WHEN 52 THEN 'EIC' WHEN 53 THEN 'EKA' WHEN 54 THEN 'EII' WHEN 55 THEN 'IAG' 
                                      WHEN 56 THEN 'ICE' WHEN 57 THEN 'KAE' WHEN 58 THEN 'IEC' WHEN 59 THEN 'IGA' WHEN 60 THEN 'KEA'
                                      WHEN 61 THEN 'IMA' WHEN 62 THEN 'FDA' WHEN 63 THEN 'OAA' WHEN 64 THEN 'ABH' WHEN 65 THEN 'ADF' 
                                      WHEN 66 THEN 'BAH' WHEN 67 THEN 'BDE' WHEN 68 THEN 'DAF' WHEN 69 THEN 'DBE' WHEN 70 THEN 'AFD'
                                      WHEN 71 THEN 'AHB' WHEN 72 THEN 'BED' WHEN 73 THEN 'BHA' WHEN 74 THEN 'DEB' WHEN 75 THEN 'DFA' 
                                      WHEN 76 THEN 'HBA' WHEN 77 THEN 'FAD' WHEN 78 THEN 'MIA' WHEN 79 THEN 'HAB' WHEN 80 THEN 'CMA'
                                      WHEN 81 THEN 'ABN' WHEN 82 THEN 'BAN' WHEN 83 THEN 'BBM' WHEN 84 THEN 'ANB' WHEN 85 THEN 'BMB' 
                                      WHEN 86 THEN 'BNA' WHEN 87 THEN 'MBB' WHEN 88 THEN 'NAB' WHEN 89 THEN 'NBA' WHEN 90 THEN 'EEM'
                                      WHEN 91 THEN 'EME' WHEN 92 THEN 'MEE' WHEN 93 THEN 'AAO' WHEN 94 THEN 'ACM' WHEN 95 THEN 'CAM' 
                                      WHEN 96 THEN 'AMC' WHEN 97 THEN 'AOA' WHEN 98 THEN 'MAC' WHEN 99 THEN 'MCA' WHEN 100 THEN 'AIM'
                                      WHEN 101 THEN 'AMI' WHEN 102 THEN 'IAM' WHEN 103 THEN 'MAI' WHEN 104 THEN 'EDB' WHEN 105 THEN 'EBD' 
                                      WHEN 106 THEN 'EBJ' END
   
   SET @v_printable_string = RTRIM(@v_printable_string) + @v_convcode
   	
   --Allow the string to return to the proper size.      
   SET @v_return = 'EBJ' + RTRIM(@v_printable_string) + 'GIAH'
   
   RETURN @v_return
END

GO