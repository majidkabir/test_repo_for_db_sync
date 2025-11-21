SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:  fnc_GetInv04Label                                         */
/* Creation Date: 04-Jul-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-2338 - New Customer Invoice (ANF TMALL) - CN            */
/*                                                                      */
/* Called By:  fnc_invoice_03                                           */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 18/09/2019   WLChooi   1.1   WMS-10586 - Add new column, revised     */
/*                              TotalQty (WL01)                         */
/* 10/02/2020   CSCHONG   1.2   WMS-11893 add new field (CS01)          */
/* 24/08/2021   WLChooi   1.3   WMS-17817 - Change Lottable02 to Channel*/
/*                              (WL02)                                  */
/* 07-Aug-2023  WLChooi   1.4   WMS-23330 - Add new field (WL03)        */
/************************************************************************/

CREATE   FUNCTION [dbo].[fnc_GetInv04Label] ( 
      @c_Orderkey NVARCHAR(10) 
) RETURNS @RetInv04Lbl TABLE 
         (     Orderkey       NVARCHAR(10) 
            ,  B19            NVARCHAR(4000)  
            ,  B8             NVARCHAR(4000)  
            ,  B15_1          NVARCHAR(4000)  
            ,  B15_2          NVARCHAR(4000) 
            ,  B17            NVARCHAR(4000)  
            ,  C1             NVARCHAR(4000)  
            ,  C3             NVARCHAR(4000)  
            ,  C5             NVARCHAR(4000)  
            ,  C7             NVARCHAR(4000)  
            ,  C9             NVARCHAR(4000)  
            ,  D1_2           NVARCHAR(4000)  
            ,  D4             NVARCHAR(4000)  
            ,  D3             NVARCHAR(4000)  
            ,  D10            NVARCHAR(4000)   
            ,  D12            NVARCHAR(4000) 
            ,  D6             NVARCHAR(4000) 
            ,  D7             NVARCHAR(4000) 
            ,  D9             NVARCHAR(4000)
            ,  D17            NVARCHAR(4000) 
            ,  D19            NVARCHAR(4000) 
            ,  C9_1           NVARCHAR(4000)  
            ,  C10_2          NVARCHAR(4000) 
            ,  E2             NVARCHAR(4000)   
            ,  E3             NVARCHAR(4000)   
            ,  E4             NVARCHAR(4000)    
            ,  E5             NVARCHAR(4000) 
            ,  E8             NVARCHAR(4000)   
            ,  E9             NVARCHAR(4000) 
            ,  E10            NVARCHAR(4000)  
            ,  E11            NVARCHAR(4000) 
            ,  E12            NVARCHAR(4000) 
            ,  E13            NVARCHAR(4000) 
            ,  E14            NVARCHAR(4000) 
            ,  E1             NVARCHAR(4000)  
            ,  E7             NVARCHAR(4000)  
            --,  F12             NVARCHAR(4000)  
            ,  C11            NVARCHAR(4000)     --WL01
            ,  E15            NVARCHAR(4000)     --CS01
            ,  E16            NVARCHAR(4000)     --CS01
            ,  E6             NVARCHAR(4000)   --WL03
            ,  E11_1          NVARCHAR(4000)   --WL03
            ,  E11_2          NVARCHAR(4000)   --WL03
            ,  E11_3          NVARCHAR(4000)   --WL03
            ,  E11_4          NVARCHAR(4000)   --WL03
            ,  E11_5          NVARCHAR(4000)   --WL03
            ,  E11_6          NVARCHAR(4000)   --WL03
         )                                   
AS
BEGIN
   SET QUOTED_IDENTIFIER OFF

   DECLARE  @c_LabelName       NVARCHAR(60)
         ,  @c_LabelValue      NVARCHAR(4000)   
         --,  @c_A2              NVARCHAR(4000)
         --,  @c_A3_1            NVARCHAR(4000)
         --,  @c_A3_2            NVARCHAR(4000)
         ,  @c_B19            NVARCHAR(4000)
         ,  @c_B8             NVARCHAR(4000)
         ,  @c_B15_1          NVARCHAR(4000)
         ,  @c_B15_2          NVARCHAR(4000)
         ,  @c_B17            NVARCHAR(4000)
         ,  @c_C1             NVARCHAR(4000)
         ,  @c_C3             NVARCHAR(4000)
         ,  @c_C5             NVARCHAR(4000)
         ,  @c_C7             NVARCHAR(4000)
         ,  @c_C9             NVARCHAR(4000)
         ,  @c_D1_2           NVARCHAR(4000)
         ,  @c_D3             NVARCHAR(4000)
         ,  @c_D4             NVARCHAR(4000)
         ,  @c_D10            NVARCHAR(4000)
         ,  @c_D12            NVARCHAR(4000)
         ,  @c_D6             NVARCHAR(4000)
         ,  @c_D7             NVARCHAR(4000)
         ,  @c_D9             NVARCHAR(4000)
         ,  @c_D17            NVARCHAR(4000)
         ,  @c_D19            NVARCHAR(4000)
         ,  @c_C9_1           NVARCHAR(4000)
         ,  @c_C10_2          NVARCHAR(4000)
         ,  @c_E2             NVARCHAR(4000)
         ,  @c_E3             NVARCHAR(4000)
         ,  @c_E4             NVARCHAR(4000)
         ,  @c_E5             NVARCHAR(4000)
         ,  @c_E8             NVARCHAR(4000)
         ,  @c_E9             NVARCHAR(4000)
         ,  @c_E10            NVARCHAR(4000)
         ,  @c_E11            NVARCHAR(4000)
         ,  @c_E1             NVARCHAR(4000)
         ,  @c_E12            NVARCHAR(4000)
         ,  @c_E13            NVARCHAR(4000)
         ,  @c_E14            NVARCHAR(4000)
         ,  @c_E7             NVARCHAR(4000)
         ,  @c_notes          NVARCHAR(4000)
         ,  @c_Udf01          NVARCHAR(4000) 
         ,  @c_Udf01a         NVARCHAR(4000) 
         ,  @c_MCompany       NVARCHAR(45)      
         ,  @c_MAddress1      NVARCHAR(45) 
         ,  @c_C11            NVARCHAR(4000)     --WL01  
         ,  @c_E15            NVARCHAR(4000)     --CS01
         ,  @c_E16            NVARCHAR(4000)     --CS01
         ,  @c_E6             NVARCHAR(4000)     --WL03
         ,  @c_E11_1          NVARCHAR(4000)     --WL03
         ,  @c_E11_2          NVARCHAR(4000)     --WL03
         ,  @c_E11_3          NVARCHAR(4000)     --WL03
         ,  @c_E11_4          NVARCHAR(4000)     --WL03
         ,  @c_E11_5          NVARCHAR(4000)     --WL03
         ,  @c_E11_6          NVARCHAR(4000)     --WL03

   SET @c_LabelName = ''
   SET @c_LabelValue= ''
   SET @c_B19   = ''   
   SET @c_B8   = ''   
   SET @c_B15_1 = ''  
   SET @c_B15_2 = ''   
   SET @c_B17  = ''    
   SET @c_C1   = ''   
   SET @c_C3   = ''   
   SET @c_C5   = ''   
   SET @c_C7   = ''   
   SET @c_C9   = ''  
   SET @c_D1_2 = ''   
   SET @c_D4   = ''   
   SET @c_D3   = ''   
   SET @c_D10  = ''     
   SET @c_D12  = ''   
   SET @c_D6   = '' 
   SET @c_D7   = '' 
   SET @c_D9   = '' 
   SET @c_D17  = ''
   SET @c_D19  = ''  
   SET @c_C10_2 = '' 
   SET @c_C9_1  = ''   
   SET @c_E2   = ''      
   SET @c_E3   = ''   
   SET @c_E4   = ''    
   SET @c_E5   = ''   
   SET @c_E8   = ''     
   SET @c_E9   = ''   
   SET @c_E10  = '' 
   SET @c_E11  = ''   
   SET @c_E1   = '' 
   SET @c_E12  = '' 
   SET @c_E13  = '' 
   SET @c_E14  = ''  
   SET @c_E7   = ''   
   SET @c_MCompany = ''        
   SET @c_MAddress1 = ''  
   SET @c_C11  = ''      --WL01   
   SET @c_E15  = ''      --CS01
   SET @c_E16  = ''      --CS01

   --WL03 S
   SET @c_E6 = ''
   SET @c_E11_1 = ''
   SET @c_E11_2 = ''
   SET @c_E11_3 = ''
   SET @c_E11_4 = ''
   SET @c_E11_5 = ''
   SET @c_E11_6 = ''
   --WL03 E

   /*CS02 start*/
   DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
    SELECT udf01 = REPLACE(udf01, '-', '_')
          ,CL.Notes
          ,CL.Notes2
          ,LEFT(udf01,1)
          , CONVERT(FLOAT, SUBSTRING(REPLACE(udf01, '-', '.'), 2,3))   
         -- ,ISNULL(OH.M_Company,''),ISNULL(OH.M_Address1,'') 
   FROM ORDERS OH WITH (NOLOCK)
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'AFTmallCV') 
                                     AND CL.storerkey = OH.storerkey
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

   WHILE @@FETCH_STATUS <> -1
   BEGIN  

      SET @c_B19   =  CASE WHEN @c_LabelName = 'B19'    THEN @c_LabelValue ELSE @c_B19   END   
      SET @c_B8    =  CASE WHEN @c_LabelName = 'B8'     THEN @c_LabelValue ELSE @c_B8   END   
      SET @c_B15_1 =  CASE WHEN @c_LabelName = 'B15_1'  THEN @c_LabelValue ELSE @c_B15_1  END   
      SET @c_B15_2 =  CASE WHEN @c_LabelName = 'B15_2'  THEN @c_LabelValue ELSE @c_B15_2  END 
      SET @c_B17   =  CASE WHEN @c_LabelName = 'B17'    THEN @c_LabelValue ELSE @c_B17  END     
      SET @c_C1    =  CASE WHEN @c_LabelName  = 'C1'    THEN @c_LabelValue ELSE @c_C1   END   
      SET @c_C3    =  CASE WHEN @c_LabelName  = 'C3'    THEN @c_LabelValue ELSE @c_C3   END   
      SET @c_C5    =  CASE WHEN @c_LabelName  = 'C5'    THEN @c_LabelValue ELSE @c_C5   END   
      SET @c_C7    =  CASE WHEN @c_LabelName = 'C7'     THEN @c_LabelValue ELSE @c_C7   END   
      SET @c_C9    =  CASE WHEN @c_LabelName = 'C9'     THEN @c_LabelValue ELSE @c_C9   END   
      SET @c_D1_2  =  CASE WHEN @c_LabelName = 'D1_2'   THEN @c_LabelValue ELSE @c_D1_2   END   
      SET @c_D4    =  CASE WHEN @c_LabelName = 'D4'     THEN @c_LabelValue ELSE @c_D4   END   
      SET @c_D3    =  CASE WHEN @c_LabelName = 'D3'     THEN @c_LabelValue ELSE @c_D3   END   
      SET @c_D10   =  CASE WHEN @c_LabelName = 'D10'    THEN @c_LabelValue ELSE @c_D10  END     
      SET @c_D12   =  CASE WHEN @c_LabelName = 'D12'    THEN @c_LabelValue ELSE @c_D12  END 
      SET @c_D6    =  CASE WHEN @c_LabelName = 'D6'     THEN @c_LabelValue ELSE @c_D6  END  
      SET @c_D7    =  CASE WHEN @c_LabelName = 'D7'     THEN @c_LabelValue ELSE @c_D7  END  
      SET @c_D17   =  CASE WHEN @c_LabelName = 'D17'    THEN @c_LabelValue ELSE @c_D17  END  
      SET @c_D19   =  CASE WHEN @c_LabelName = 'D19'    THEN @c_LabelValue ELSE @c_D19  END    
      SET @c_D9    =  CASE WHEN @c_LabelName = 'D9'     THEN @c_LabelValue  ELSE @c_D9  END    
      SET @c_C9_1  =  CASE WHEN @c_LabelName = 'C9_1'   THEN @c_LabelValue  ELSE @c_C9_1   END        
      SET @c_C10_2  =  CASE WHEN @c_LabelName = 'C10_2' THEN @c_LabelValue ELSE @c_C10_2   END   
      --SET @c_E2   =  CASE WHEN @c_LabelName = 'E2'      THEN @c_LabelValue ELSE @c_E2   END   --WL03     
      --SET @c_E3   =  CASE WHEN @c_LabelName = 'E3'      THEN @c_LabelValue ELSE @c_E3   END   --WL03      
      --SET @c_E4   =  CASE WHEN @c_LabelName = 'E4'      THEN @c_LabelValue ELSE @c_E4   END   --WL03     
      --SET @c_E5   =  CASE WHEN @c_LabelName = 'E5'      THEN @c_LabelValue ELSE @c_E5   END   --WL03   
      --SET @c_E8   =  CASE WHEN @c_LabelName = 'E8'      THEN @c_LabelValue ELSE @c_E8   END   --WL03      
      --SET @c_E9   =  CASE WHEN @c_LabelName = 'E9'      THEN @c_LabelValue ELSE @c_E9   END   --WL03 
      SET @c_E10  =  CASE WHEN @c_LabelName = 'E10'     THEN @c_LabelValue ELSE @c_E10  END  
      SET @c_E11  =  CASE WHEN @c_LabelName = 'E11'     THEN @c_LabelValue ELSE @c_E11  END 
      SET @c_E1   =  CASE WHEN @c_LabelName = 'E1'      THEN @c_LabelValue ELSE @c_E1   END  
      SET @c_E12  =  CASE WHEN @c_LabelName = 'E12'     THEN @c_LabelValue ELSE @c_E12  END  
      --SET @c_E13  =  CASE WHEN @c_LabelName = 'E13'     THEN @c_LabelValue ELSE @c_E13  END   --WL03  
      SET @c_E7   =  CASE WHEN @c_LabelName = 'E7'      THEN @c_LabelValue ELSE @c_E7  END       
      SET @c_C11  =  CASE WHEN @c_LabelName = 'C11'     THEN @c_LabelValue ELSE @c_C11 END    --WL01
      --WL03 S
      SET @c_E11_1 = CASE WHEN @c_LabelName = 'E11_1'   THEN @c_LabelValue ELSE @c_E11_1 END
      SET @c_E11_2 = CASE WHEN @c_LabelName = 'E11_2'   THEN @c_LabelValue ELSE @c_E11_2 END
      SET @c_E11_3 = CASE WHEN @c_LabelName = 'E11_3'   THEN @c_LabelValue ELSE @c_E11_3 END
      SET @c_E11_4 = CASE WHEN @c_LabelName = 'E11_4'   THEN @c_LabelValue ELSE @c_E11_4 END
      SET @c_E11_5 = CASE WHEN @c_LabelName = 'E11_5'   THEN @c_LabelValue ELSE @c_E11_5 END
      SET @c_E11_6 = CASE WHEN @c_LabelName = 'E11_6'   THEN @c_LabelValue ELSE @c_E11_6 END
      --WL03 E
      
      FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                                ,  @c_LabelValue
                                ,  @c_notes           
                                ,  @c_Udf01              
                                ,  @c_Udf01a         

   END
   CLOSE CUR_LBL
   DEALLOCATE CUR_LBL

   SET @c_E14 = ''
   SELECT TOP 1 @c_E14 = CL.notes
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'AFTmallCV') 
                                   AND CL.storerkey = OH.storerkey
                                   AND (CL.UDF03 = OD.Channel)   --WL02
                                   AND CL.UDF01 like 'E14%'              --CS01
   WHERE OH.Orderkey = @c_orderkey

   --CS01 START
   SET @c_E15 = ''
   SET @c_E16 = ''
   
   SELECT TOP 1 @c_E15 = CL.notes
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'AFTmallCV') 
                                   AND CL.storerkey = OH.storerkey
                                   AND (CL.UDF03 = OD.Channel)   --WL02
                                   AND CL.UDF01 like 'E15%'              --CS01
   WHERE OH.Orderkey = @c_orderkey
   
   SELECT TOP 1 @c_E16 = CL.notes
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'AFTmallCV') 
                                   AND CL.storerkey = OH.storerkey
                                   AND (CL.UDF03 = OD.Channel)   --WL02
                                   AND CL.UDF01 like 'E16%'              --CS01
   WHERE OH.Orderkey = @c_orderkey
   --CS01 END 

   --WL03 S
   SET @c_E2 = ''
   SET @c_E3 = ''
   SET @c_E4 = ''
   SET @c_E5 = ''
   SET @c_E6 = ''
   SET @c_E8 = ''
   SET @c_E9 = ''
   SET @c_E13 = ''

   SELECT TOP 1 @c_E13 = CL.notes
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OD.OrderKey = OH.OrderKey)
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'AFTmallCV') 
                                   AND (CL.StorerKey = OH.StorerKey)
                                   AND (CL.UDF03 = OD.Channel)
                                   AND (CL.UDF01 LIKE 'E13%')
   WHERE OH.Orderkey = @c_Orderkey

   SELECT @c_E2 = ISNULL(MAX(CASE WHEN CL.UDF01 LIKE 'E2%' THEN CL.Notes ELSE '' END), '')
        , @c_E3 = ISNULL(MAX(CASE WHEN CL.UDF01 LIKE 'E3%' THEN CL.Notes ELSE '' END), '')
        , @c_E4 = ISNULL(MAX(CASE WHEN CL.UDF01 LIKE 'E4%' THEN CL.Notes ELSE '' END), '')
        , @c_E5 = ISNULL(MAX(CASE WHEN CL.UDF01 LIKE 'E5%' THEN CL.Notes ELSE '' END), '')
        , @c_E6 = ISNULL(MAX(CASE WHEN CL.UDF01 LIKE 'E6%' THEN CL.Notes ELSE '' END), '')
        , @c_E8 = ISNULL(MAX(CASE WHEN CL.UDF01 LIKE 'E8%' THEN CL.Notes ELSE '' END), '')
        , @c_E9 = ISNULL(MAX(CASE WHEN CL.UDF01 LIKE 'E9%' THEN CL.Notes ELSE '' END), '')
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OD.OrderKey = OH.OrderKey)
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'AFTmallCV') 
                                   AND (CL.StorerKey = OH.StorerKey)
                                   AND (CL.UDF03 = OD.Channel)
                                   AND (CL.UDF04 = OH.ECOM_Platform)
                                   AND (CL.UDF01 LIKE 'E2%' OR
                                        CL.UDF01 LIKE 'E3%' OR
                                        CL.UDF01 LIKE 'E4%' OR
                                        CL.UDF01 LIKE 'E5%' OR
                                        CL.UDF01 LIKE 'E6%' OR
                                        CL.UDF01 LIKE 'E8%' OR
                                        CL.UDF01 LIKE 'E9%' )
   WHERE OH.Orderkey = @c_Orderkey
   --WL03 E

   INSERT INTO @RetInv04Lbl
         (  Orderkey                 
         ,  B19            
         ,  B8             
         ,  B15_1
         ,  B15_2            
         ,  B17                       
         ,  C1             
         ,  C3             
         ,  C5             
         ,  C7             
         ,  C9           
         ,  D1_2             
         ,  D4             
         ,  D3             
         ,  D10                      
         ,  D12  
         ,  D6    
         ,  D7     
         ,  D9
         ,  D17 
         ,  D19 
         ,  C10_2  
         ,  C9_1          
         ,  E2                     
         ,  E3           
         ,  E4                    
         ,  E5             
         ,  E8                      
         ,  E9 
         ,  E10            
         ,  E11
         ,  E1
         ,  E12 
         ,  E13 
         ,  E14           
         ,  E7
         ,  C11   --WL01
         ,  E15   --CS01
         ,  E16   --CS01
         ,  E6    --WL03
         ,  E11_1 --WL03
         ,  E11_2 --WL03
         ,  E11_3 --WL03
         ,  E11_4 --WL03
         ,  E11_5 --WL03
         ,  E11_6 --WL03
         )
   SELECT @c_Orderkey
         ,  @c_B19    
         ,  @c_B8    
         ,  @c_B15_1  
         ,  @c_B15_2 
         ,  @c_B17     
         ,  @c_C1    
         ,  @c_C3    
         ,  @c_C5    
         ,  @c_C7    
         ,  @c_C9    
         ,  @c_D1_2    
         ,  @c_D4    
         ,  @c_D3   
         ,  @c_D10     
         ,  @c_D12  
         ,  @c_D6  
         ,  @c_D7 
         ,  @c_D9
         ,  @c_D17 
         ,  @c_D19
         ,  @c_C10_2  
         ,  @c_C9_1  
         ,  @c_E2   
         ,  @c_E3   
         ,  @c_E4  
         ,  @c_E5    
         ,  @c_E8    
         ,  @c_E9  
         ,  @c_E10  
         ,  @c_E11   
         ,  @c_E1
         ,  @c_E12
         ,  @c_E13
         ,  @c_E14 
         ,  @c_E7
         ,  @c_C11   --WL01
         ,  @c_E15   --CS01
         ,  @c_E16   --CS01
         ,  @c_E6    --WL03
         ,  @c_E11_1 --WL03
         ,  @c_E11_2 --WL03
         ,  @c_E11_3 --WL03
         ,  @c_E11_4 --WL03
         ,  @c_E11_5 --WL03
         ,  @c_E11_6 --WL03

   RETURN
END

GO