SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function:  fnc_GetInv03Label                                         */
/* Creation Date: 04-Jul-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-2187 - New CSE Invoice (A&F DTC Order) (HK&CN)          */
/*                                                                      */
/* Called By:  fnc_invoice_03                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2019-Sep-18  WLChooi   1.1   WMS-10586 - Add new column, revised     */
/*                              TotalQty (WL01)                         */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetInv03Label] ( 
      @c_Orderkey NVARCHAR(10) 
) RETURNS @RetInvLbl TABLE 
         (     Orderkey       NVARCHAR(10)
            ,  A2             NVARCHAR(4000) 
            ,  A3_1           NVARCHAR(4000) 
            ,  A3_2           NVARCHAR(4000)    
            ,  B1            	NVARCHAR(4000)  
            ,  B8            	NVARCHAR(4000)  
            ,  B15_1         	NVARCHAR(4000)  
            ,  B15_2         	NVARCHAR(4000) 
            ,  B17           	NVARCHAR(4000)  
            ,  C1            	NVARCHAR(4000)  
            ,  C3            	NVARCHAR(4000)  
            ,  C5            	NVARCHAR(4000)  
            ,  C7            	NVARCHAR(4000)  
            ,  C9            	NVARCHAR(4000)  
            ,  D1            	NVARCHAR(4000)  
            ,  D4            	NVARCHAR(4000)  
            ,  D7            	NVARCHAR(4000)  
            ,  D10           	NVARCHAR(4000)   
            ,  D17           	NVARCHAR(4000) 
            ,  D20           	NVARCHAR(4000) 
            ,  D23           	NVARCHAR(4000)
            ,  D24           	NVARCHAR(4000)  
            ,  E1           	NVARCHAR(4000) 
            ,  E2          	NVARCHAR(4000)   
            ,  E3          	NVARCHAR(4000)   
            ,  E4          	NVARCHAR(4000)    
            ,  E5            	NVARCHAR(4000) 
            ,  E6            	NVARCHAR(4000)   
            ,  E9            	NVARCHAR(4000) 
            ,  E10          	NVARCHAR(4000)  
            ,  E11_1         	NVARCHAR(4000)  
            ,  E11_2         	NVARCHAR(4000) 
            ,  E12          	NVARCHAR(4000) 
            ,  E13          	NVARCHAR(4000) 
            ,  E14          	NVARCHAR(4000) 
            ,  F11          	NVARCHAR(4000)  
            ,  F13           	NVARCHAR(4000)  
            ,  F12           	NVARCHAR(4000)  
            ,  E17          	NVARCHAR(4000) 
            ,  E18          	NVARCHAR(4000) 
            ,  C11            NVARCHAR(4000)  --WL01

         )                                   
AS
BEGIN
   SET QUOTED_IDENTIFIER OFF

   DECLARE  @c_LabelName       NVARCHAR(60)
         ,  @c_LabelValue      NVARCHAR(4000)   
         ,  @c_A2					NVARCHAR(4000)
         ,  @c_A3_1				NVARCHAR(4000)
         ,  @c_A3_2				NVARCHAR(4000)
         ,  @c_B1       		NVARCHAR(4000)
         ,  @c_B8       		NVARCHAR(4000)
         ,  @c_B15_1     		NVARCHAR(4000)
         ,  @c_B15_2     		NVARCHAR(4000)
         ,  @c_B17      		NVARCHAR(4000)
         ,  @c_C1       		NVARCHAR(4000)
         ,  @c_C3       		NVARCHAR(4000)
         ,  @c_C5       		NVARCHAR(4000)
         ,  @c_C7       		NVARCHAR(4000)
         ,  @c_C9       		NVARCHAR(4000)
         ,  @c_D1       		NVARCHAR(4000)
         ,  @c_D4       		NVARCHAR(4000)
         ,  @c_D7       		NVARCHAR(4000)
         ,  @c_D10      		NVARCHAR(4000)
         ,  @c_D17      		NVARCHAR(4000)
         ,  @c_D20      		NVARCHAR(4000)
         ,  @c_D23     		   NVARCHAR(4000)
         ,  @c_D24      		NVARCHAR(4000)
         ,  @c_E1       		NVARCHAR(4000)
         ,  @c_E2       		NVARCHAR(4000)
         ,  @c_E3       		NVARCHAR(4000)
         ,  @c_E4       		NVARCHAR(4000)
         ,  @c_E5       		NVARCHAR(4000)
         ,  @c_E6       		NVARCHAR(4000)
         ,  @c_E9       		NVARCHAR(4000)
         ,  @c_E10       		NVARCHAR(4000)
         ,  @c_E11_1      		NVARCHAR(4000)
         ,  @c_E11_2      		NVARCHAR(4000)
         ,  @c_E12       		NVARCHAR(4000)
         ,  @c_E13       		NVARCHAR(4000)
         ,  @c_E14       		NVARCHAR(4000)
         ,  @c_F11       		NVARCHAR(4000)
         ,  @c_F13       		NVARCHAR(4000)
         ,  @c_F12       		NVARCHAR(4000)
         ,  @c_notes          NVARCHAR(4000)
         ,  @c_Udf01          NVARCHAR(4000) 
         ,  @c_Udf01a         NVARCHAR(4000) 
			,  @c_MCompany       NVARCHAR(45)      
         ,  @c_MAddress1      NVARCHAR(45)   
         ,  @c_E17       		NVARCHAR(4000)
         ,  @c_E18       		NVARCHAR(4000)   
         ,  @c_C11            NVARCHAR(4000)  --WL01 


   SET @c_LabelName = ''
   SET @c_LabelValue= ''
   SET @c_A2   = ''  
   SET @c_A3_1 = ''  
   SET @c_A3_2 = '' 
   SET @c_B1   = ''   
   SET @c_B8   = ''   
   SET @c_B15_1 = ''  
   SET @c_B15_2 = ''   
   SET @c_B17  = ''    
   SET @c_C1   = ''   
   SET @c_C3   = ''   
   SET @c_C5   = ''   
   SET @c_C7   = ''   
   SET @c_C9   = ''  
   SET @c_D1   = ''   
   SET @c_D4   = ''   
   SET @c_D7   = ''   
   SET @c_D10  = ''     
   SET @c_D17  = ''   
   SET @c_D20  = '' 
   SET @c_D23  = '' 
   SET @c_D24  = '' 
   SET @c_E1   = ''   
   SET @c_E2   = ''      
   SET @c_E3   = ''   
   SET @c_E4   = ''    
   SET @c_E5   = ''   
   SET @c_E6   = ''     
   SET @c_E9   = ''   
   SET @c_E10  = '' 
   SET @c_E11_1  = ''   
   SET @c_E11_2  = '' 
   SET @c_E12  = '' 
   SET @c_E13  = '' 
   SET @c_E14  = ''  
   SET @c_F11   = ''   
   SET @c_F13   = ''   
   SET @c_F12   = ''   
   SET @c_MCompany = ''        
	SET @c_MAddress1 = ''   
	SET @c_E17  = '' 
   SET @c_E18  = '' 
   SET @c_C11  = '' --WL01    


	/*CS02 start*/
   DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
    SELECT udf01 = REPLACE(udf01, '-', '_')
         ,CL.Notes
         ,CL.Notes2
         ,LEFT(udf01,1)
          , CONVERT(FLOAT, SUBSTRING(REPLACE(udf01, '-', '.'), 2,3))   
          ,ISNULL(OH.M_Company,''),ISNULL(OH.M_Address1,'') 
   FROM ORDERS OH WITH (NOLOCK)
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'AFCustInvo') 
                                     --AND(CL.Storerkey = OH.Storerkey)
                                     AND(CL.UDF02 = OH.Userdefine10)
                                      AND ISNULL(RTRIM(CL.UDF03),'') = OH.C_Country
                                     AND CL.storerkey = OH.storerkey
                                     AND LEFT(UDF01,1) <> 'E'                
                                     AND LEFT(UDF01,3) NOT IN ('D23','D24')      
                                    -- AND (CL.UDF03 = OH.C_Country)
                                    --AND (CL.UDF04 = OH.SectionKey)
   WHERE OH.Orderkey = @c_orderkey
   --ORDER BY LEFT(udf01,1)
   --       , CONVERT(FLOAT, SUBSTRING(REPLACE(udf01, '-', '.'), 2,3))      
   UNION
   SELECT udf01 = REPLACE(udf01, '-', '_')
         ,CL.Notes
         ,CL.Notes2
         ,LEFT(udf01,1)
          , CONVERT(FLOAT, SUBSTRING(REPLACE(udf01, '-', '.'), 2,3))   
          ,ISNULL(OH.M_Company,''),ISNULL(OH.M_Address1,'') 
   FROM ORDERS OH WITH (NOLOCK)
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'AFCustInvo') 
                                     --AND(CL.Storerkey = OH.Storerkey)
                                     AND(CL.UDF02 = OH.Userdefine10)
                                      AND ISNULL(RTRIM(CL.UDF03),'') = OH.C_Country
                                     AND CL.storerkey = OH.storerkey
                                      AND (LEFT(UDF01,1) = 'E'               
                                     OR LEFT(UDF01,3) IN ('D23','D24'))       
                                    -- AND (CL.UDF03 = OH.C_Country)
                                    AND (CL.UDF04 = OH.SectionKey)
   WHERE OH.Orderkey = @c_orderkey
   ORDER BY LEFT(udf01,1)
          , CONVERT(FLOAT, SUBSTRING(REPLACE(udf01, '-', '.'), 2,3))       
          
   /*CS02 End*/
          
   OPEN CUR_LBL

   FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                             ,  @c_LabelValue
                             ,  @c_notes            
                             ,  @c_Udf01             
                             ,  @c_Udf01a     
                             ,  @c_MCompany           
                             ,  @c_MAddress1       
      

   WHILE @@FETCH_STATUS <> -1
   BEGIN  
      SET @c_A2   =  CASE WHEN @c_LabelName = 'A2'   THEN @c_LabelValue ELSE @c_A2   END 
      SET @c_A3_1 =  CASE WHEN @c_LabelName = 'A3_1' THEN @c_LabelValue ELSE @c_A3_1 END
      SET @c_A3_2 =  CASE WHEN @c_LabelName = 'A3_2' THEN @c_LabelValue ELSE @c_A3_2 END  
      SET @c_B1   =  CASE WHEN @c_LabelName = 'B1'   THEN @c_LabelValue ELSE @c_B1   END   
      SET @c_B8   =  CASE WHEN @c_LabelName = 'B8'   THEN @c_LabelValue ELSE @c_B8   END   
      SET @c_B15_1 =  CASE WHEN @c_LabelName = 'B15_1'  THEN @c_LabelValue ELSE @c_B15_1  END   
      SET @c_B15_2 =  CASE WHEN @c_LabelName = 'B15_2'  THEN @c_LabelValue ELSE @c_B15_2  END 
      SET @c_B17  =  CASE WHEN @c_LabelName = 'B17'  THEN @c_LabelValue ELSE @c_B17  END     
      SET @c_C1   =  CASE WHEN @c_LabelName = 'C1'   THEN @c_LabelValue ELSE @c_C1   END   
      SET @c_C3   =  CASE WHEN @c_LabelName = 'C3'   THEN @c_LabelValue ELSE @c_C3   END   
      SET @c_C5   =  CASE WHEN @c_LabelName = 'C5'   THEN @c_LabelValue ELSE @c_C5   END   
      SET @c_C7   =  CASE WHEN @c_LabelName = 'C7'   THEN @c_LabelValue ELSE @c_C7   END   
      SET @c_C9   =  CASE WHEN @c_LabelName = 'C9'   THEN @c_LabelValue ELSE @c_C9   END   
      SET @c_D1   =  CASE WHEN @c_LabelName = 'D1'   THEN @c_LabelValue ELSE @c_D1   END   
      SET @c_D4   =  CASE WHEN @c_LabelName = 'D4'   THEN @c_LabelValue ELSE @c_D4   END   
      SET @c_D7   =  CASE WHEN @c_LabelName = 'D7'   THEN @c_LabelValue ELSE @c_D7   END   
      SET @c_D10  =  CASE WHEN @c_LabelName = 'D10'  THEN @c_LabelValue ELSE @c_D10  END     
      SET @c_D17  =  CASE WHEN @c_LabelName = 'D17'  THEN @c_LabelValue ELSE @c_D17  END 
      SET @c_D20  =  CASE WHEN @c_LabelName = 'D20'  THEN @c_LabelValue ELSE @c_D20  END    
      SET @c_D23  =  CASE WHEN @c_LabelName = 'D23'  AND @c_MAddress1 <>''  THEN @c_MAddress1  ELSE @c_D23  END    
      SET @c_D24  =  CASE WHEN @c_LabelName = 'D24'  THEN @c_MCompany  ELSE @c_D24  END        
      SET @c_E1   =  CASE WHEN @c_LabelName = 'E1'   THEN @c_LabelValue ELSE @c_E1   END   
      SET @c_E2   =  CASE WHEN @c_LabelName = 'E2'   THEN @c_LabelValue ELSE @c_E2   END     
      SET @c_E3   =  CASE WHEN @c_LabelName = 'E3'   THEN @c_LabelValue ELSE @c_E3   END      
      SET @c_E4   =  CASE WHEN @c_LabelName = 'E4'   THEN @c_LabelValue ELSE @c_E4   END     
      SET @c_E5   =  CASE WHEN @c_LabelName = 'E5'   THEN @c_LabelValue ELSE @c_E5   END   
      SET @c_E6   =  CASE WHEN @c_LabelName = 'E6'   THEN @c_LabelValue ELSE @c_E6   END      
      SET @c_E9   =  CASE WHEN @c_LabelName = 'E9'   THEN @c_LabelValue ELSE @c_E9   END 
      SET @c_E10  =  CASE WHEN @c_LabelName = 'E10'  THEN @c_LabelValue ELSE @c_E10  END  
      SET @c_E11_1  =  CASE WHEN @c_LabelName = 'E11_1'  THEN @c_LabelValue ELSE @c_E11_1  END 
      SET @c_E11_2  =  CASE WHEN @c_LabelName = 'E11_2'  THEN @c_LabelValue ELSE @c_E11_2  END  
      SET @c_E12  =  CASE WHEN @c_LabelName = 'E12'  THEN @c_LabelValue ELSE @c_E12  END  
      SET @c_E13  =  CASE WHEN @c_LabelName = 'E13'  THEN @c_LabelValue ELSE @c_E13  END  
      SET @c_E14  =  CASE WHEN @c_LabelName = 'E14'  THEN @c_LabelValue ELSE @c_E14  END      
      SET @c_F11  =  CASE WHEN @c_LabelName = 'F11'  THEN @c_LabelValue ELSE @c_F11  END   
      SET @c_F12  =  CASE WHEN @c_LabelName = 'F12'  THEN @c_LabelValue ELSE @c_F12  END   
      SET @c_F13  =  CASE WHEN @c_LabelName = 'F13'  THEN @c_LabelValue ELSE @c_F13  END  
      SET @c_E17  =  CASE WHEN @c_LabelName = 'E17'  THEN @c_LabelValue ELSE @c_E17  END  
      SET @c_E18  =  CASE WHEN @c_LabelName = 'E18'  THEN @c_LabelValue ELSE @c_E18  END       
      SET @c_C11  =  CASE WHEN @c_LabelName = 'C11'  THEN @c_LabelValue ELSE @c_C11  END   --WL01
      
      FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                                ,  @c_LabelValue
                                ,  @c_notes           
                                ,  @c_Udf01              
                                ,  @c_Udf01a  
                                ,  @c_MCompany           
                                ,  @c_MAddress1           

   END
   CLOSE CUR_LBL
   DEALLOCATE CUR_LBL



   INSERT INTO @RetInvLbl
		   (	Orderkey       
         ,  A2 
         ,  A3_1
         ,  A3_2           
         ,  B1             
         ,  B8             
         ,  B15_1
         ,  B15_2            
         ,  B17                       
         ,  C1             
         ,  C3             
         ,  C5             
         ,  C7             
         ,  C9           
         ,  D1             
         ,  D4             
         ,  D7             
         ,  D10                      
         ,  D17   
         ,  D20        
         ,  D23
         ,  D24           
         ,  E1          
         ,  E2                     
         ,  E3           
         ,  E4                    
         ,  E5             
         ,  E6                      
         ,  E9 
         ,  E10            
         ,  E11_1
         ,  E11_2 
         ,  E12 
         ,  E13 
         ,  E14           
         ,  F11             
         ,  F12            
         ,  F13
         ,  E17
         ,  E18
         ,  C11   --WL01
         )
   SELECT @c_Orderkey
         ,  @c_A2	
         ,  @c_A3_1
         ,  @c_A3_2	
         ,  @c_B1    
         ,  @c_B8    
         ,  @c_B15_1  
         ,  @c_B15_2 
         ,  @c_B17     
         ,  @c_C1    
         ,  @c_C3    
         ,  @c_C5    
         ,  @c_C7    
         ,  @c_C9    
         ,  @c_D1    
         ,  @c_D4    
         ,  @c_D7    
         ,  @c_D10     
         ,  @c_D17   
         ,  @c_D20   
         ,  @c_D23
         ,  @c_D24  
         ,  @c_E1  
         ,  @c_E2   
         ,  @c_E3   
         ,  @c_E4  
         ,  @c_E5    
         ,  @c_E6    
         ,  @c_E9  
         ,  @c_E10  
         ,  @c_E11_1   
         ,  @c_E11_2 
         ,  @c_E12
         ,  @c_E13
         ,  @c_E14 
         ,  @c_F11    
         ,  @c_F12   
         ,  @c_F13
         ,  @c_E17
         ,  @c_E18
         ,  @c_C11   --WL01


   RETURN
END

GO