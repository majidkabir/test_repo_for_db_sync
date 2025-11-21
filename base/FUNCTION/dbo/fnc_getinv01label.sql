SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:  fnc_GetInv01Label                                         */
/* Creation Date: 23-Jul-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        : SOS#315902 - ANF DTC Customer Invoice Report                */
/*                                                                      */
/* Called By:  fnc_invoice_01_2                                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2015-AUG-14  CSCHONG   1.0   SOS#349820 (CS01)                       */
/* 2016-AUG-24  CSCHONG   2.0   WMS-245- Add QR code (CS02)             */
/* 2017-Feb-20  CSCHONG   2.1   WMS-1102 - Add and change mapping (CS03)*/
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetInv01Label] ( 
      @c_Orderkey NVARCHAR(10) 
) RETURNS @RetInvLbl TABLE 
         (     Orderkey       NVARCHAR(10)
            ,  A2             NVARCHAR(4000)   
            ,  B1             NVARCHAR(4000)  
            ,  B8             NVARCHAR(4000)  
            ,  B15            NVARCHAR(4000)  
            ,  B17            NVARCHAR(4000)  
            ,  B19            NVARCHAR(4000)  
            ,  C1             NVARCHAR(4000)  
            ,  C3             NVARCHAR(4000)  
            ,  C5             NVARCHAR(4000)  
            ,  C7             NVARCHAR(4000)  
            ,  C9             NVARCHAR(4000)  
            ,  C12            NVARCHAR(4000)
            ,  D1             NVARCHAR(4000)  
            ,  D4             NVARCHAR(4000)  
            ,  D7             NVARCHAR(4000)  
            ,  D10            NVARCHAR(4000)  
            ,  D13            NVARCHAR(4000)  
            ,  D17            NVARCHAR(4000)  
            ,  E1_1           NVARCHAR(4000) 
            ,  E1_2           NVARCHAR(4000)  
            ,  E2_1           NVARCHAR(4000)  
            ,  E2_2           NVARCHAR(4000)  
            ,  E3_1           NVARCHAR(4000)  
            ,  E3_2           NVARCHAR(4000)  
            ,  E4_1           NVARCHAR(4000)  
            ,  E4_2           NVARCHAR(4000)  
            ,  E4_3           NVARCHAR(4000)  
            ,  E5             NVARCHAR(4000)  
            ,  E7             NVARCHAR(4000)  
            ,  E8_1           NVARCHAR(4000)  
            ,  E8_2           NVARCHAR(4000)  
            ,  E8_3           NVARCHAR(4000)  
            ,  E9             NVARCHAR(4000)  
            ,  E11            NVARCHAR(4000)  
            ,  F1             NVARCHAR(4000)  
            ,  F3             NVARCHAR(4000)  
            ,  F5             NVARCHAR(4000)  
            ,  F7             NVARCHAR(4000)  
            ,  F9             NVARCHAR(4000)  
            ,  F11            NVARCHAR(4000) 
            ,  D20            NVARCHAR(4000)           --(CS01)
            ,  E13            NVARCHAR(4000)           --(CS02)
            ,  G1             NVARCHAR(4000)           --(CS03)
            ,  G2             NVARCHAR(4000)           --(CS03)
            ,  G3             NVARCHAR(4000)           --(CS03)
            ,  E3_3           NVARCHAR(4000)           --(CS03)
            ,  E3_4           NVARCHAR(4000)           --(CS03)
            ,  E3_5           NVARCHAR(4000)           --(CS03)
         )                                   
AS
BEGIN
   SET QUOTED_IDENTIFIER OFF

   DECLARE  @c_LabelName       NVARCHAR(60)
         ,  @c_LabelValue      NVARCHAR(4000)   
         
         ,  @c_A2             NVARCHAR(4000)
         ,  @c_B1             NVARCHAR(4000)
         ,  @c_B8             NVARCHAR(4000)
         ,  @c_B15            NVARCHAR(4000)
         ,  @c_B17            NVARCHAR(4000)
         ,  @c_B19            NVARCHAR(4000)
         ,  @c_C1             NVARCHAR(4000)
         ,  @c_C3             NVARCHAR(4000)
         ,  @c_C5             NVARCHAR(4000)
         ,  @c_C7             NVARCHAR(4000)
         ,  @c_C9             NVARCHAR(4000)
         ,  @c_C12            NVARCHAR(4000)
         ,  @c_D1             NVARCHAR(4000)
         ,  @c_D4             NVARCHAR(4000)
         ,  @c_D7             NVARCHAR(4000)
         ,  @c_D10            NVARCHAR(4000)
         ,  @c_D13            NVARCHAR(4000)
         ,  @c_D17            NVARCHAR(4000)
         ,  @c_E1_1           NVARCHAR(4000)
         ,  @c_E1_2           NVARCHAR(4000)
         ,  @c_E2_1           NVARCHAR(4000)
         ,  @c_E2_2           NVARCHAR(4000)
         ,  @c_E3_1           NVARCHAR(4000)
         ,  @c_E3_2           NVARCHAR(4000)
         ,  @c_E4_1           NVARCHAR(4000)
         ,  @c_E4_2           NVARCHAR(4000)
         ,  @c_E4_3           NVARCHAR(4000)
         ,  @c_E5             NVARCHAR(4000)
         ,  @c_E7             NVARCHAR(4000)
         ,  @c_E8_1           NVARCHAR(4000)
         ,  @c_E8_2           NVARCHAR(4000)
         ,  @c_E8_3           NVARCHAR(4000)
         ,  @c_E9             NVARCHAR(4000)
         ,  @c_E11            NVARCHAR(4000)
         ,  @c_F1             NVARCHAR(4000)
         ,  @c_F3             NVARCHAR(4000)
         ,  @c_F5             NVARCHAR(4000)
         ,  @c_F7             NVARCHAR(4000)
         ,  @c_F9             NVARCHAR(4000)
         ,  @c_F11            NVARCHAR(4000)
         ,  @c_D20            NVARCHAR(4000)     --(CS01)
         ,  @c_E13            NVARCHAR(4000)     --(CS02)
         ,  @c_Udf01          NVARCHAR(4000)     --(CS02)
         ,  @c_Udf01a         NVARCHAR(4000)     --(CS02)
         ,  @c_notes2         NVARCHAR(4000)     --(CS02)
         ,  @c_G1             NVARCHAR(4000)     --(CS03)
         ,  @c_G2             NVARCHAR(4000)     --(CS03)
         ,  @c_G3             NVARCHAR(4000)     --(CS03)
         ,  @c_MCompany       NVARCHAR(45)       --(CS03)
         ,  @c_MAddress1      NVARCHAR(45)       --(CS03)
         ,  @c_E3_3           NVARCHAR(4000)     --(CS03)
         ,  @c_E3_4           NVARCHAR(4000)     --(CS03)
         ,  @c_E3_5           NVARCHAR(4000)     --(CS03) 

   SET @c_LabelName = ''
   SET @c_LabelValue= ''
   SET @c_A2   = ''   
   SET @c_B1   = ''   
   SET @c_B8   = ''   
   SET @c_B15  = ''   
   SET @c_B17  = ''   
   SET @c_B19  = ''   
   SET @c_C1   = ''   
   SET @c_C3   = ''   
   SET @c_C5   = ''   
   SET @c_C7   = ''   
   SET @c_C9   = ''  
   SET @c_C12  = '' 
   SET @c_D1   = ''   
   SET @c_D4   = ''   
   SET @c_D7   = ''   
   SET @c_D10  = ''   
   SET @c_D13  = ''   
   SET @c_D17  = ''   
   SET @c_E1_1 = ''   
   SET @c_E1_2 = ''   
   SET @c_E2_1 = ''   
   SET @c_E2_2 = ''   
   SET @c_E3_1 = ''   
   SET @c_E3_2 = ''   
   SET @c_E4_1 = ''   
   SET @c_E4_2 = ''   
   SET @c_E4_3 = ''   
   SET @c_E5   = ''   
   SET @c_E7   = ''   
   SET @c_E8_1 = ''   
   SET @c_E8_2 = ''   
   SET @c_E8_3 = ''   
   SET @c_E9   = ''   
   SET @c_E11  = ''   
   SET @c_F1   = ''   
   SET @c_F3   = ''   
   SET @c_F5   = ''   
   SET @c_F7   = ''   
   SET @c_F9   = ''   
   SET @c_F11  = ''   
   SET @c_D20  = ''            --(CS01)
   SET @c_E13  = ''            --(CS02)
   SET @c_Udf01 = ''           --(CS02)
   SET @c_Udf01a = ''          --(CS02)
   SET @c_notes2 = ''          --(CS02)
   SET @c_G1     = ''          --(CS03)
   SET @c_G2     = ''          --(CS03)
   SET @c_G3     = ''          --(CS03)
   SET @c_MCompany = ''        --(CS03)
   SET @c_MAddress1 = ''       --(CS03)
   SET @c_E3_3 = ''            --(CS03)
   SET @c_E3_4 = ''            --(CS03)
   SET @c_E3_5 = ''            --(CS03)

   /*CS02 start*/
   DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
   SELECT udf01 = REPLACE(udf01, '-', '_')
         ,CL.Notes
         ,CL.Notes2
         ,LEFT(udf01,1)
         , CONVERT(FLOAT, SUBSTRING(REPLACE(udf01, '-', '.'), 2,3))  
         ,ISNULL(OH.M_Company,''),ISNULL(OH.M_Address1,'')               --(CS03) 
   FROM ORDERS OH WITH (NOLOCK)
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'CustInvo') 
                                     --AND(CL.Storerkey = OH.Storerkey)
                                     AND(CL.UDF02 = OH.Userdefine10)
                                     -- AND (CL.UDF03 = '')
                                    --  AND (CL.UDF04 = '')
                                     --AND CL.UDF01 NOT LIKE 'E%'            --(CS03)
                                    AND LEFT(UDF01,1) NOT IN ('E','G')       --(CS03) 
   WHERE OH.Orderkey = @c_orderkey
   UNION
    SELECT udf01 = REPLACE(udf01, '-', '_')
         ,CL.Notes
         ,CL.Notes2
         ,LEFT(udf01,1)
         , CONVERT(FLOAT, SUBSTRING(REPLACE(udf01, '-', '.'), 2,3))  
         ,ISNULL(OH.M_Company,''),ISNULL(OH.M_Address1,'')               --(CS03)  
   FROM ORDERS OH WITH (NOLOCK)
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'CustInvo') 
                                     --AND(CL.Storerkey = OH.Storerkey)
                                     AND(CL.UDF02 = OH.Userdefine10)
                                      AND ( (ISNULL(RTRIM(CL.UDF03),'')= '') OR 
                                             (ISNULL(RTRIM(CL.UDF03),'') <> '' AND ISNULL(RTRIM(CL.UDF03),'') = OH.C_Country) )
                                     AND ( (ISNULL(RTRIM(CL.UDF04),'')= '') OR 
                                             (ISNULL(RTRIM(CL.UDF04),'') <> '' AND ISNULL(RTRIM(CL.UDF04),'') = OH.SectionKey) )
                                     --AND UDF01 LIKE 'E%'                --(CS03)
                                     AND LEFT(UDF01,1) IN ('E','G')       --(CS03) 
                                    -- AND (CL.UDF03 = OH.C_Country)
                                    --AND (CL.UDF04 = OH.SectionKey)
   WHERE OH.Orderkey = @c_orderkey
   ORDER BY LEFT(udf01,1)
          , CONVERT(FLOAT, SUBSTRING(REPLACE(udf01, '-', '.'), 2,3))
          
   /*CS02 End*/
          
   OPEN CUR_LBL

   FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                             ,  @c_LabelValue
                             ,  @c_notes2             --(CS02)
                             ,  @c_Udf01              --(CS02)
                             ,  @c_Udf01a             --(CS02)
                             ,  @c_MCompany           --(CS03)
                             ,  @c_MAddress1          --(CS03)

   WHILE @@FETCH_STATUS <> -1
   BEGIN  
      SET @c_A2   =  CASE WHEN @c_LabelName = 'A2'   THEN @c_LabelValue ELSE @c_A2   END   
      SET @c_B1   =  CASE WHEN @c_LabelName = 'B1'   THEN @c_LabelValue ELSE @c_B1   END   
      SET @c_B8   =  CASE WHEN @c_LabelName = 'B8'   THEN @c_LabelValue ELSE @c_B8   END   
      SET @c_B15  =  CASE WHEN @c_LabelName = 'B15'  THEN @c_LabelValue ELSE @c_B15  END   
      SET @c_B17  =  CASE WHEN @c_LabelName = 'B17'  THEN @c_LabelValue ELSE @c_B17  END   
      SET @c_B19  =  CASE WHEN @c_LabelName = 'B19'  THEN @c_LabelValue ELSE @c_B19  END   
      SET @c_C1   =  CASE WHEN @c_LabelName = 'C1'   THEN @c_LabelValue ELSE @c_C1   END   
      SET @c_C3   =  CASE WHEN @c_LabelName = 'C3'   THEN @c_LabelValue ELSE @c_C3   END   
      SET @c_C5   =  CASE WHEN @c_LabelName = 'C5'   THEN @c_LabelValue ELSE @c_C5   END   
      SET @c_C7   =  CASE WHEN @c_LabelName = 'C7'   THEN @c_LabelValue ELSE @c_C7   END   
      SET @c_C9   =  CASE WHEN @c_LabelName = 'C9'   THEN @c_LabelValue ELSE @c_C9   END 
      SET @c_C12  =  CASE WHEN @c_LabelName = 'C12'  THEN @c_LabelValue ELSE @c_C12  END   
      SET @c_D1   =  CASE WHEN @c_LabelName = 'D1'   THEN @c_LabelValue ELSE @c_D1   END   
      SET @c_D4   =  CASE WHEN @c_LabelName = 'D4'   THEN @c_LabelValue ELSE @c_D4   END   
      SET @c_D7   =  CASE WHEN @c_LabelName = 'D7'   THEN @c_LabelValue ELSE @c_D7   END   
      SET @c_D10  =  CASE WHEN @c_LabelName = 'D10'  THEN @c_LabelValue ELSE @c_D10  END   
      SET @c_D13  =  CASE WHEN @c_LabelName = 'D13'  THEN @c_LabelValue ELSE @c_D13  END   
      SET @c_D17  =  CASE WHEN @c_LabelName = 'D17'  THEN @c_LabelValue ELSE @c_D17  END   
      SET @c_E1_1 =  CASE WHEN @c_LabelName = 'E1_1' THEN @c_LabelValue ELSE @c_E1_1 END   
      SET @c_E1_2 =  CASE WHEN @c_LabelName = 'E1_2' THEN @c_LabelValue ELSE @c_E1_2 END   
      SET @c_E2_1 =  CASE WHEN @c_LabelName = 'E2_1' THEN @c_LabelValue ELSE @c_E2_1 END   
      SET @c_E2_2 =  CASE WHEN @c_LabelName = 'E2_2' THEN @c_LabelValue ELSE @c_E2_2 END   
      SET @c_E3_1 =  CASE WHEN @c_LabelName = 'E3_1' THEN @c_LabelValue ELSE @c_E3_1 END   
      SET @c_E3_2 =  CASE WHEN @c_LabelName = 'E3_2' THEN @c_LabelValue ELSE @c_E3_2 END      
      SET @c_E4_1 =  CASE WHEN @c_LabelName = 'E4_1' THEN @c_LabelValue ELSE @c_E4_1 END   
      SET @c_E4_2 =  CASE WHEN @c_LabelName = 'E4_2' THEN @c_LabelValue ELSE @c_E4_2 END   
      SET @c_E4_3 =  CASE WHEN @c_LabelName = 'E4_3' THEN @c_LabelValue ELSE @c_E4_3 END   
      SET @c_E5   =  CASE WHEN @c_LabelName = 'E5'   THEN @c_LabelValue ELSE @c_E5   END   
      SET @c_E7   =  CASE WHEN @c_LabelName = 'E7'   THEN @c_LabelValue ELSE @c_E7   END   
      SET @c_E8_1 =  CASE WHEN @c_LabelName = 'E8_1' THEN @c_LabelValue ELSE @c_E8_1 END   
      SET @c_E8_2 =  CASE WHEN @c_LabelName = 'E8_2' THEN @c_LabelValue ELSE @c_E8_2 END   
      SET @c_E8_3 =  CASE WHEN @c_LabelName = 'E8_3' THEN @c_LabelValue ELSE @c_E8_3 END   
      SET @c_E9   =  CASE WHEN @c_LabelName = 'E9'   THEN @c_LabelValue ELSE @c_E9   END   
      SET @c_E11  =  CASE WHEN @c_LabelName = 'E11'  THEN @c_LabelValue ELSE @c_E11  END   
      SET @c_F1   =  CASE WHEN @c_LabelName = 'F1'   THEN @c_LabelValue ELSE @c_F1   END   
      SET @c_F3   =  CASE WHEN @c_LabelName = 'F3'   THEN @c_LabelValue ELSE @c_F3   END   
      SET @c_F5   =  CASE WHEN @c_LabelName = 'F5'   THEN @c_LabelValue ELSE @c_F5   END   
      SET @c_F7   =  CASE WHEN @c_LabelName = 'F7'   THEN @c_LabelValue ELSE @c_F7   END   
      SET @c_F9   =  CASE WHEN @c_LabelName = 'F9'   THEN @c_LabelValue ELSE @c_F9   END   
      SET @c_F11  =  CASE WHEN @c_LabelName = 'F11'  THEN @c_LabelValue ELSE @c_F11  END   
      SET @c_D20  =  CASE WHEN @c_LabelName = 'D20'  THEN @c_LabelValue ELSE @c_D20  END       --(CS01)
      SET @c_E13  =  CASE WHEN @c_LabelName = 'E13'  THEN @c_notes2     ELSE @c_E13  END       --(CS01)
      SET @c_G1   =  CASE WHEN @c_LabelName = 'G1' AND @c_MAddress1 <>''  THEN @c_LabelValue     ELSE @c_G1   END       --(CS03)
      SET @c_G2   =  CASE WHEN @c_LabelName = 'G2' AND @c_MAddress1 <>''  THEN @c_MAddress1     ELSE @c_G2   END       --(CS03)
      SET @c_G3   =  CASE WHEN @c_LabelName = 'G3'   THEN @c_MCompany     ELSE @c_G3   END       --(CS03)
      SET @c_E3_3 =  CASE WHEN @c_LabelName = 'E3_3' THEN @c_LabelValue ELSE @c_E3_3 END        --(CS03)
      SET @c_E3_4 =  CASE WHEN @c_LabelName = 'E3_4' THEN @c_LabelValue ELSE @c_E3_4 END        --(CS03)
      SET @c_E3_5 =  CASE WHEN @c_LabelName = 'E3_5' THEN @c_LabelValue ELSE @c_E3_5 END        --(CS03)
      
      FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                                ,  @c_LabelValue
                                ,  @c_notes2             --(CS02)
                                ,  @c_Udf01              --(CS02)
                                ,  @c_Udf01a             --(CS02)
                                ,  @c_MCompany           --(CS03)
                                ,  @c_MAddress1          --(CS03)
   END
   CLOSE CUR_LBL
   DEALLOCATE CUR_LBL



   INSERT INTO @RetInvLbl
         (  Orderkey       
         ,  A2             
         ,  B1             
         ,  B8             
         ,  B15            
         ,  B17            
         ,  B19            
         ,  C1             
         ,  C3             
         ,  C5             
         ,  C7             
         ,  C9
         ,  C12             
         ,  D1             
         ,  D4             
         ,  D7             
         ,  D10            
         ,  D13            
         ,  D17            
         ,  E1_1           
         ,  E1_2           
         ,  E2_1           
         ,  E2_2           
         ,  E3_1           
         ,  E3_2           
         ,  E4_1           
         ,  E4_2           
         ,  E4_3           
         ,  E5             
         ,  E7             
         ,  E8_1           
         ,  E8_2           
         ,  E8_3           
         ,  E9             
         ,  E11            
         ,  F1             
         ,  F3             
         ,  F5             
         ,  F7             
         ,  F9             
         ,  F11 
         ,  D20       --(CS01)   
         ,  E13       --(CS02)   
         ,  G1        --(CS03)     
         ,  G2        --(CS03) 
         ,  G3        --(CS03)    
         ,  E3_3      --(CS03)
         ,  E3_4      --(CS03)
         ,  E3_5      --(CS03)
         )
   SELECT @c_Orderkey
         ,  @c_A2    
         ,  @c_B1    
         ,  @c_B8    
         ,  @c_B15   
         ,  @c_B17   
         ,  @c_B19   
         ,  @c_C1    
         ,  @c_C3    
         ,  @c_C5    
         ,  @c_C7    
         ,  @c_C9
         ,  @c_C12     
         ,  @c_D1    
         ,  @c_D4    
         ,  @c_D7    
         ,  @c_D10   
         ,  @c_D13   
         ,  @c_D17   
         ,  @c_E1_1  
         ,  @c_E1_2  
         ,  @c_E2_1  
         ,  @c_E2_2  
         ,  @c_E3_1  
         ,  @c_E3_2  
         ,  @c_E4_1  
         ,  @c_E4_2  
         ,  @c_E4_3  
         ,  @c_E5    
         ,  @c_E7    
         ,  @c_E8_1  
         ,  @c_E8_2  
         ,  @c_E8_3  
         ,  @c_E9    
         ,  @c_E11   
         ,  @c_F1    
         ,  @c_F3    
         ,  @c_F5    
         ,  @c_F7    
         ,  @c_F9    
         ,  @c_F11  
         ,  @c_D20           --(CS01)
         ,  @c_E13           --(CS02)
         ,  @c_G1            --(CS03)
         ,  @c_G2            --(CS03)
         ,  @c_G3            --(CS03)
         ,  @c_E3_3          --(CS03) 
         ,  @c_E3_4          --(CS03) 
         ,  @c_E3_5          --(CS03) 

   RETURN
END

GO