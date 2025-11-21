SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function:  fnc_manifest_by_load13                                    */
/* Creation Date: 10-AUG-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-5151 - CN WMS MHD POD                                   */
/*                                                                      */
/* Called By:  isp_shipping_manifest_by_load_13                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE FUNCTION [dbo].fnc_manifest_by_load13 ( 
                  @c_orderkey NVARCHAR(20) 
) RETURNS @Retmanifest_by_load13 TABLE 
         (     Orderkey       NVARCHAR(20)
			   ,  C01           	NVARCHAR(4000) 
            ,  C02           	NVARCHAR(4000)     
            ,  C03           	NVARCHAR(4000)
            ,  C04           	NVARCHAR(4000)    
            ,  C05           	NVARCHAR(4000) 
            ,  C06           	NVARCHAR(4000)  
            ,  C07           	NVARCHAR(4000)                  
            ,  C08           	NVARCHAR(4000) 
            ,  C09           	NVARCHAR(4000)     
            ,  C10           	NVARCHAR(4000)
            ,  C11          	NVARCHAR(4000)    
            ,  C12           	NVARCHAR(4000) 
            ,  C13           	NVARCHAR(4000)  
            ,  C14          	NVARCHAR(4000) 
				,  C15           	NVARCHAR(4000)
            ,  C16          	NVARCHAR(4000)    
            ,  C17           	NVARCHAR(4000) 
            ,  C18           	NVARCHAR(4000)  
            ,  C19          	NVARCHAR(4000) 
				,  C20           	NVARCHAR(4000)
            ,  C21          	NVARCHAR(4000)    
            ,  C22           	NVARCHAR(4000) 
            ,  C23           	NVARCHAR(4000)  
            ,  C24          	NVARCHAR(4000)  
				,  C25           	NVARCHAR(4000)
            ,  C26          	NVARCHAR(4000)    
            ,  C27           	NVARCHAR(4000) 
            ,  C28           	NVARCHAR(4000)  
            ,  C29          	NVARCHAR(4000)  
				,  C30           	NVARCHAR(4000)
            ,  C31          	NVARCHAR(4000)    
            ,  C32           	NVARCHAR(4000) 
            ,  C33           	NVARCHAR(4000)  
            ,  C34          	NVARCHAR(4000)                  
            ,  C35           	NVARCHAR(4000) 
            ,  C36           	NVARCHAR(4000)  
            ,  C37          	NVARCHAR(4000)        

         )                                   
AS
BEGIN
   SET QUOTED_IDENTIFIER OFF

   DECLARE  @c_LabelName      NVARCHAR(60)
         ,  @c_LabelValue     NVARCHAR(4000)   
         ,  @c_C01       		NVARCHAR(4000)
         ,  @c_C02       		NVARCHAR(4000)
         ,  @c_C03       		NVARCHAR(4000)
         ,  @c_C04       		NVARCHAR(4000)
         ,  @c_C05       		NVARCHAR(4000)
         ,  @c_C06       		NVARCHAR(4000)
         ,  @c_C07       		NVARCHAR(4000)         
         ,  @c_C08       		NVARCHAR(4000)
         ,  @c_C09       		NVARCHAR(4000)
         ,  @c_C10       		NVARCHAR(4000)

         ,  @c_C11       		NVARCHAR(4000)
         ,  @c_C12       		NVARCHAR(4000)
         ,  @c_C13      		NVARCHAR(4000)
         ,  @c_C14       		NVARCHAR(4000) 
         ,  @c_C15       		NVARCHAR(4000)
         ,  @c_C16       		NVARCHAR(4000)
         ,  @c_C17      		NVARCHAR(4000)
         ,  @c_C18       		NVARCHAR(4000)
		   ,  @c_C19       		NVARCHAR(4000)
         ,  @c_C20       		NVARCHAR(4000)

         ,  @c_C21      		NVARCHAR(4000)
         ,  @c_C22       		NVARCHAR(4000)
			,  @c_C23      		NVARCHAR(4000)
         ,  @c_C24       		NVARCHAR(4000)
			,  @c_C25      		NVARCHAR(4000)
         ,  @c_C26       		NVARCHAR(4000)
			,  @c_C27      		NVARCHAR(4000)
         ,  @c_C28       		NVARCHAR(4000)
			,  @c_C29      		NVARCHAR(4000)
         ,  @c_C30       		NVARCHAR(4000)

			,  @c_C31      		NVARCHAR(4000)
         ,  @c_C32       		NVARCHAR(4000)
			,  @c_C33      		NVARCHAR(4000)
         ,  @c_C34       		NVARCHAR(4000)
			,  @c_C35      		NVARCHAR(4000)
         ,  @c_C36       		NVARCHAR(4000)
			,  @c_C37       		NVARCHAR(4000)
          


   SET @c_LabelName = ''
   SET @c_LabelValue= ''
 
   SET @c_C01   = '' 
   SET @c_C02   = ''    
   SET @c_C03   = ''   
   SET @c_C04   = '' 
   SET @c_C05   = ''   
   SET @c_C06   = '' 
   SET @c_C07   = '' 
	SET @c_C08   = '' 
   SET @c_C09   = ''    
   SET @c_C10  = '' 
	  
   SET @c_C11  = '' 
   SET @c_C12  = ''   
   SET @c_C13  = '' 
   SET @c_C14  = ''  
   SET @c_C15  = ''   
   SET @c_C16  = '' 
   SET @c_C17  = ''   
   SET @c_C18  = '' 
   SET @c_C19  = ''  

	SET @c_C20  = ''   
   SET @c_C21  = '' 
   SET @c_C22  = ''   
   SET @c_C23  = '' 
   SET @c_C24  = ''
	SET @c_C25  = ''   
   SET @c_C26  = '' 
   SET @c_C27  = ''   
   SET @c_C28  = '' 
   SET @c_C29  = ''    


	SET @c_C30  = ''   
   SET @c_C31  = '' 
   SET @c_C32  = ''   
   SET @c_C33  = '' 
   SET @c_C34  = '' 
	SET @c_C35  = ''   
   SET @c_C36  = '' 
   SET @c_C37  = '' 

   DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
    SELECT CL.code
         , CL.Notes
   FROM ORDERS OH WITH (NOLOCK)
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'PODHCODE') 
                                     AND CL.storerkey = OH.storerkey
   
   WHERE OH.Orderkey = @c_Orderkey     
   
   OPEN CUR_LBL

   FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                             ,  @c_LabelValue
                           
      

   WHILE @@FETCH_STATUS <> -1
   BEGIN  
	   SET @c_C01    =  CASE WHEN @c_LabelName = 'C01'    THEN @c_LabelValue ELSE @c_C01   END 
      SET @c_C02    =  CASE WHEN @c_LabelName = 'C02'    THEN @c_LabelValue ELSE @c_C02   END    
      SET @c_C03    =  CASE WHEN @c_LabelName = 'C03'    THEN @c_LabelValue ELSE @c_C03   END 
      SET @c_C04    =  CASE WHEN @c_LabelName = 'C04'    THEN @c_LabelValue ELSE @c_C04   END   
      SET @c_C05    =  CASE WHEN @c_LabelName = 'C05'    THEN @c_LabelValue ELSE @c_C05   END  
      SET @c_C06    =  CASE WHEN @c_LabelName = 'C06'    THEN @c_LabelValue ELSE @c_C06   END   
      SET @c_C07    =  CASE WHEN @c_LabelName = 'C07'    THEN @c_LabelValue ELSE @c_C07   END   
   	SET @c_C08    =  CASE WHEN @c_LabelName = 'C08'    THEN @c_LabelValue ELSE @c_C08   END 
      SET @c_C09    =  CASE WHEN @c_LabelName = 'C09'    THEN @c_LabelValue ELSE @c_C09   END 
      SET @c_C10   =  CASE WHEN @c_LabelName = 'C10'   THEN @c_LabelValue ELSE @c_C10   END
		SET @c_C11   =  CASE WHEN @c_LabelName = 'C11'   THEN @c_LabelValue ELSE @c_C11   END 
      SET @c_C12   =  CASE WHEN @c_LabelName = 'C12'   THEN @c_LabelValue ELSE @c_C12   END    
      SET @c_C13   =  CASE WHEN @c_LabelName = 'C13'   THEN @c_LabelValue ELSE @c_C13   END 
      SET @c_C14   =  CASE WHEN @c_LabelName = 'C14'   THEN @c_LabelValue ELSE @c_C14   END   
      SET @c_C15   =  CASE WHEN @c_LabelName = 'C15'   THEN @c_LabelValue ELSE @c_C15   END  
      SET @c_C16   =  CASE WHEN @c_LabelName = 'C16'   THEN @c_LabelValue ELSE @c_C16   END   
      SET @c_C17   =  CASE WHEN @c_LabelName = 'C17'   THEN @c_LabelValue ELSE @c_C17   END   
   	SET @c_C18   =  CASE WHEN @c_LabelName = 'C18'   THEN @c_LabelValue ELSE @c_C18   END 
      SET @c_C19   =  CASE WHEN @c_LabelName = 'C19'   THEN @c_LabelValue ELSE @c_C19   END 
      SET @c_C20   =  CASE WHEN @c_LabelName = 'C20'   THEN @c_LabelValue ELSE @c_C20   END
      SET @c_C21   =  CASE WHEN @c_LabelName = 'C21'   THEN @c_LabelValue ELSE @c_C21   END 
      SET @c_C22   =  CASE WHEN @c_LabelName = 'C22'   THEN @c_LabelValue ELSE @c_C22   END    
      SET @c_C23   =  CASE WHEN @c_LabelName = 'C23'   THEN @c_LabelValue ELSE @c_C23   END 
      SET @c_C24   =  CASE WHEN @c_LabelName = 'C24'   THEN @c_LabelValue ELSE @c_C24   END   
      SET @c_C25   =  CASE WHEN @c_LabelName = 'C25'   THEN @c_LabelValue ELSE @c_C25   END  
      SET @c_C26   =  CASE WHEN @c_LabelName = 'C26'   THEN @c_LabelValue ELSE @c_C26   END   
      SET @c_C27   =  CASE WHEN @c_LabelName = 'C27'   THEN @c_LabelValue ELSE @c_C27   END   
   	SET @c_C28   =  CASE WHEN @c_LabelName = 'C28'   THEN @c_LabelValue ELSE @c_C28   END 
      SET @c_C29   =  CASE WHEN @c_LabelName = 'C29'   THEN @c_LabelValue ELSE @c_C29   END 
      SET @c_C30   =  CASE WHEN @c_LabelName = 'C30'   THEN @c_LabelValue ELSE @c_C30   END
		SET @c_C31   =  CASE WHEN @c_LabelName = 'C31'   THEN @c_LabelValue ELSE @c_C31   END
		SET @c_C32   =  CASE WHEN @c_LabelName = 'C32'   THEN @c_LabelValue ELSE @c_C32   END
		SET @c_C33   =  CASE WHEN @c_LabelName = 'C33'   THEN @c_LabelValue ELSE @c_C33   END
		SET @c_C34   =  CASE WHEN @c_LabelName = 'C34'   THEN @c_LabelValue ELSE @c_C34   END
		SET @c_C35   =  CASE WHEN @c_LabelName = 'C35'   THEN @c_LabelValue ELSE @c_C35   END
		SET @c_C36   =  CASE WHEN @c_LabelName = 'C36'   THEN @c_LabelValue ELSE @c_C36   END
		SET @c_C37   =  CASE WHEN @c_LabelName = 'C37'   THEN @c_LabelValue ELSE @c_C37   END
                    
      FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                                ,  @c_LabelValue

   END
   CLOSE CUR_LBL
   DEALLOCATE CUR_LBL



   INSERT INTO @Retmanifest_by_load13
		   (	Orderkey  
	      ,  C01
         ,  C02             
         ,  C03
         ,  C04             
         ,  C05
         ,  C06             
         ,  C07
			,  C08
         ,  C09             
         ,  C10
         ,  C11             
         ,  C12
         ,  C13             
         ,  C14  
			,  C15
         ,  C16             
         ,  C17
         ,  C18             
         ,  C19
			,  C20    
			,  C21
			,  C22
			,  C23
			,  C24    
			,  C25
			,  C26
			,  C27
			,  C28   
			,  C29
			,  C30
			,  C31
			,  C32
			,  C33
			,  C34
			,  C35
			,  C36
			,  C37     
         )
   SELECT @c_orderkey
         ,  @c_C01 
         ,  @c_C02   
         ,  @c_C03
         ,  @c_C04    
         ,  @c_C05
         ,  @c_C06    
         ,  @c_C07 
			,  @c_C08 
         ,  @c_C09   
         ,  @c_C10
         ,  @c_C11    
         ,  @c_C12
         ,  @c_C13   
         ,  @c_C14 
			,  @c_C15
         ,  @c_C16    
         ,  @c_C17
         ,  @c_C18  
         ,  @c_C19
			,  @c_C20
			,  @c_C21
			,  @c_C22
			,  @c_C23
			,  @c_C24
			,  @c_C25
			,  @c_C26
			,  @c_C27
			,  @c_C28
			,  @c_C29
			,  @c_C30
			,  @c_C31
			,  @c_C32
			,  @c_C33
			,  @c_C34
			,  @c_C35
			,  @c_C36
			,  @c_C37

   RETURN
END

GO