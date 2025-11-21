SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function:  fnc_GetPacksku12Label                                     */
/* Creation Date: 06-Apr-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-4391 - CN IKEA                                          */
/*                                                                      */
/* Called By:  isp_PackListBySku12                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 27-DEC-2019  CSCHONG   1.3   WMS-11546 - revised field logic (CS01)  */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetPacksku12Label] ( 
      @c_pickslipno NVARCHAR(20) 
) RETURNS @RetPackSku12 TABLE 
         (     Pickslipno     NVARCHAR(20)
            ,  A2             NVARCHAR(4000) 
            ,  A3             NVARCHAR(4000) 
            ,  A4             NVARCHAR(4000)    
            ,  B1             NVARCHAR(4000)  
            ,  B3             NVARCHAR(4000)  
            ,  B4             NVARCHAR(4000)  
            ,  B4b            NVARCHAR(4000) 
            ,  B5             NVARCHAR(4000) 
            ,  B7             NVARCHAR(4000)  
            ,  B9             NVARCHAR(4000)  
            ,  B10            NVARCHAR(4000)  
            ,  B11            NVARCHAR(4000)  
            ,  B12            NVARCHAR(4000)  
            ,  B14            NVARCHAR(4000)  
            ,  B16            NVARCHAR(4000)  
            ,  B18            NVARCHAR(4000)  
            ,  B21            NVARCHAR(4000)  
            ,  C1             NVARCHAR(4000)   
            ,  C3             NVARCHAR(4000) 
            ,  C5             NVARCHAR(4000) 
            ,  C7             NVARCHAR(4000)
            ,  C8             NVARCHAR(4000)             --(CS01)
           
         )                                   
AS
BEGIN
   SET QUOTED_IDENTIFIER OFF

   DECLARE  @c_LabelName      NVARCHAR(60)
         ,  @c_LabelValue     NVARCHAR(4000)   
         ,  @c_A2             NVARCHAR(4000)
         ,  @c_A3             NVARCHAR(4000)
         ,  @c_A4             NVARCHAR(4000)
         ,  @c_B1             NVARCHAR(4000)
         ,  @c_B3             NVARCHAR(4000)
         ,  @c_B4             NVARCHAR(4000)
         ,  @c_B4b            NVARCHAR(4000)
         ,  @c_B5             NVARCHAR(4000)
         ,  @c_B7             NVARCHAR(4000)
         ,  @c_B9             NVARCHAR(4000)
         ,  @c_B10            NVARCHAR(4000)
         ,  @c_B11            NVARCHAR(4000)
         ,  @c_B12            NVARCHAR(4000)
         ,  @c_B14            NVARCHAR(4000)
         ,  @c_B16            NVARCHAR(4000)
         ,  @c_B18            NVARCHAR(4000)
         ,  @c_B21            NVARCHAR(4000)
         ,  @c_C1             NVARCHAR(4000)
         ,  @c_C3             NVARCHAR(4000)
         ,  @c_C5             NVARCHAR(4000)
         ,  @c_C7             NVARCHAR(4000)
         ,  @c_UDFValue       NVARCHAR(4000)
         ,  @c_C8             NVARCHAR(4000)      --(CS01)
         ,  @c_B101           NVARCHAR(4000)      --(CS01)
         ,  @c_shipperkey     NVARCHAR(20)        --(CS01)
         ,  @c_C71            NVARCHAR(4000)      --(CS01)
          


   SET @c_LabelName = ''
   SET @c_LabelValue= ''
   SET @c_A2   = ''  
   SET @c_A3   = ''  
   SET @c_A4   = '' 
   SET @c_B1   = ''   
   SET @c_B3   = ''   
   SET @c_B4   = ''  
   SET @c_B4b  = '' 
   SET @c_B5   = ''   
   SET @c_B7   = '' 
   SET @c_B9   = ''   
   SET @c_B10  = ''   
   SET @c_B11  = ''   
   SET @c_B12  = ''     
   SET @c_B14  = ''   
   SET @c_B16  = '' 
   SET @c_B18  = '' 
   SET @c_B21  = ''    
   SET @c_C1   = ''   
   SET @c_C3   = ''   
   SET @c_C5   = ''   
   SET @c_C7   = ''   
   SET @c_C8   = ''                     --(CS01)
   SET @c_shipperkey = ''               --(CS01)
   SET @c_C71   = ''                    --(CS01)
   SET @c_B101  = ''                    --(CS01)
  

   /*CS01 START*/
   SELECT TOP 1 @c_shipperkey = OH.Shipperkey
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey AND OH.Storerkey = PH.Storerkey)
   WHERE PH.Pickslipno = @c_pickslipno
   
   /*CS01 END*/

   DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
    SELECT CL.code
         , CL.Notes
         , ISNULL(CL.UDF01,'') + ISNULL(CL.UDF02,'') + ISNULL(CL.UDF03,'') + ISNULL(CL.UDF04,'')
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey AND OH.Storerkey = PH.Storerkey)
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'IKEAPACK') 
                                     AND CL.storerkey = PH.storerkey
                                     AND CL.short = OH.userdefine02
   
   WHERE PH.Pickslipno = @c_pickslipno     
          
   OPEN CUR_LBL

   FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                             ,  @c_LabelValue
                             ,  @c_UDFValue
                           
      
   WHILE @@FETCH_STATUS <> -1
   BEGIN  
      SET @c_A2   =  CASE WHEN @c_LabelName = 'A2'   THEN @c_LabelValue ELSE @c_A2   END 
      SET @c_A3   =  CASE WHEN @c_LabelName = 'A3'   THEN @c_LabelValue ELSE @c_A3   END
      SET @c_A4   =  CASE WHEN @c_LabelName = 'A4'   THEN @c_LabelValue ELSE @c_A4   END  
      SET @c_B1   =  CASE WHEN @c_LabelName = 'B1'   THEN @c_LabelValue ELSE @c_B1   END   
      SET @c_B3   =  CASE WHEN @c_LabelName = 'B3'   THEN @c_LabelValue ELSE @c_B3   END   
      SET @c_B4   =  CASE WHEN @c_LabelName = 'B4'   THEN @c_UDFValue   ELSE @c_B4   END  
      SET @c_B4b  =  CASE WHEN @c_LabelName = 'B4'   THEN @c_LabelValue ELSE @c_B4b  END   
      SET @c_B5   =  CASE WHEN @c_LabelName = 'B5'   THEN @c_LabelValue ELSE @c_B5   END 
      SET @c_B7   =  CASE WHEN @c_LabelName = 'B7'   THEN @c_LabelValue ELSE @c_B7   END 
      SET @c_B9   =  CASE WHEN @c_LabelName = 'B9'   THEN @c_LabelValue ELSE @c_B9   END   
      SET @c_B10  =  CASE WHEN @c_LabelName = 'B10'  THEN @c_LabelValue ELSE @c_B10  END   
      SET @c_B11  =  CASE WHEN @c_LabelName = 'B11'  THEN @c_LabelValue ELSE @c_B11  END   
      SET @c_B12  =  CASE WHEN @c_LabelName = 'B12'  THEN @c_LabelValue ELSE @c_B12  END     
      SET @c_B14  =  CASE WHEN @c_LabelName = 'B14'  THEN @c_LabelValue ELSE @c_B14  END 
      SET @c_B16  =  CASE WHEN @c_LabelName = 'B16'  THEN @c_LabelValue ELSE @c_B16  END    
      SET @c_B18  =  CASE WHEN @c_LabelName = 'B18'  THEN @c_LabelValue ELSE @c_B18  END   
      SET @c_B21  =  CASE WHEN @c_LabelName = 'B21'  THEN @c_LabelValue ELSE @c_B21  END         
      SET @c_C1   =  CASE WHEN @c_LabelName = 'C1'   THEN @c_LabelValue ELSE @c_C1   END   
      SET @c_C3   =  CASE WHEN @c_LabelName = 'C3'   THEN @c_LabelValue ELSE @c_C3   END   
      SET @c_C5   =  CASE WHEN @c_LabelName = 'C5'   THEN @c_LabelValue ELSE @c_C5   END   
      SET @c_C7   =  CASE WHEN @c_LabelName = 'C7'   THEN @c_LabelValue ELSE @c_C7   END   
      SET @c_C8   =  CASE WHEN @c_LabelName = 'C8'   THEN @c_LabelValue ELSE @c_C8   END          --(CS01)
      SET @c_B101 =  CASE WHEN @c_LabelName = 'B101' THEN @c_LabelValue ELSE @c_B101 END          --(CS01)
      SET @c_C71  =  CASE WHEN @c_LabelName = 'C71'  THEN @c_LabelValue ELSE @c_C71   END 
         
      
      FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                                ,  @c_LabelValue
                                ,  @c_UDFValue

   END
   CLOSE CUR_LBL
   DEALLOCATE CUR_LBL



   INSERT INTO @RetPackSku12
         (  Pickslipno       
         ,  A2 
         ,  A3
         ,  A4           
         ,  B1             
         ,  B3 
         ,  B4 
         ,  B4b           
         ,  B5
         ,  B7            
         ,  B9  
         ,  B10             
         ,  B11            
         ,  B12            
         ,  B14                      
         ,  B16   
         ,  B18        
         ,  B21                               
         ,  C1             
         ,  C3             
         ,  C5             
         ,  C7  
         ,  C8                   --(CS01)           
         )
   SELECT @c_pickslipno
         ,  @c_A2 
         ,  @c_A3
         ,  @c_A4 
         ,  @c_B1    
         ,  @c_B3    
         ,  @c_B4 
         ,  @c_B4b  
         ,  @c_B5 
         ,  @c_B7   
         ,  @c_B9    
         ,  CASE WHEN @c_shipperkey ='SN' THEN @c_B101 ELSE @c_B10 END       --(CS01)
         ,  @c_B11   
         ,  @c_B12     
         ,  @c_B14   
         ,  @c_B16   
         ,  @c_B18
         ,  @c_B21  
         ,  @c_C1    
         ,  @c_C3    
         ,  @c_C5    
         ,  CASE WHEN @c_shipperkey ='SN' THEN @c_C71 ELSE @c_C7 END         --(CS01) 
         ,  CASE WHEN @c_shipperkey ='SN' THEN @c_C8  ELSE '' END            --(CS01)   
       

   RETURN
END

GO