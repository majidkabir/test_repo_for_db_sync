SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Function:  fnc_GetPackinglist18Label                                 */  
/* Creation Date: 20-Apr-201r5                                          */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*        : SOS#339440 - Lululemon ECOM Packing List                    */  
/*                                                                      */  
/* Called By:  isp_Packing_List_18                                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */ 
/*13-DEC-2017	WLCHOO1	  1.0	WMS-3608-Updated mapping for 6-11,		*/
/*								      18-22, A1-A18 (WL01)				*/
/************************************************************************/  
  
CREATE FUNCTION [dbo].[fnc_GetPackinglist18Label] (   
		@c_Orderkey NVARCHAR(10)   
) RETURNS @RetPackList18Lbl TABLE   
			(     Orderkey       NVARCHAR(10)  
				,  A1             NVARCHAR(4000)     
				,  A2             NVARCHAR(4000)    
				,  A3             NVARCHAR(4000)    
				,  A4             NVARCHAR(4000)    
				,  A5             NVARCHAR(4000)    
				,  A6             NVARCHAR(4000)    
				,  A7             NVARCHAR(4000)    
				,  A8             NVARCHAR(4000)    
				,  A9             NVARCHAR(4000)    
				,  A10            NVARCHAR(4000)    
				,  A11            NVARCHAR(4000)    
				,  A12            NVARCHAR(4000)  
				,  A13            NVARCHAR(4000)    
				,  A14            NVARCHAR(4000)    
				,  A15            NVARCHAR(4000)    
				,  A16            NVARCHAR(4000)    
				,  A17            NVARCHAR(4000) 
				,  A18            NVARCHAR(4000)   
				  
			)                                     
AS  
BEGIN  
	SET QUOTED_IDENTIFIER OFF  
  
	DECLARE  @c_LabelName       NVARCHAR(60)  
			,  @c_LabelValue      NVARCHAR(4000)     
			  
			,  @c_A1         NVARCHAR(4000)  
			,  @c_A2         NVARCHAR(4000)  
			,  @c_A3         NVARCHAR(4000)  
			,  @c_A4         NVARCHAR(4000)  
			,  @c_A5         NVARCHAR(4000)  
			,  @c_A6         NVARCHAR(4000)  
			,  @c_A7         NVARCHAR(4000)  
			,  @c_A8         NVARCHAR(4000)  
			,  @c_A9         NVARCHAR(4000)  
			,  @c_A10        NVARCHAR(4000)  
			,  @c_A11        NVARCHAR(4000)  
			,  @c_A12        NVARCHAR(4000)  
			,  @c_A13        NVARCHAR(4000)  
			,  @c_A14        NVARCHAR(4000)  
			,  @c_A15        NVARCHAR(4000)  
			,  @c_A16        NVARCHAR(4000)  
			,  @c_A17        NVARCHAR(4000) 
			,  @c_A18        NVARCHAR(4000) 

			,  @c_A1a         NVARCHAR(4000)  
			,  @c_A2a         NVARCHAR(4000)  
			,  @c_A3a         NVARCHAR(4000)  
			,  @c_A4a         NVARCHAR(4000)  
			,  @c_A5a         NVARCHAR(4000)  
			,  @c_A6a         NVARCHAR(4000)  
			,  @c_A7a         NVARCHAR(4000)  
			,  @c_A8a         NVARCHAR(4000)  
			,  @c_A9a         NVARCHAR(4000)  
			,  @c_A10a        NVARCHAR(4000)  
			,  @c_A11a        NVARCHAR(4000)  
			,  @c_A12a        NVARCHAR(4000)  
			,  @c_A13a        NVARCHAR(4000)  
			,  @c_A14a        NVARCHAR(4000)  
			,  @c_A15a        NVARCHAR(4000)  
			,  @c_A16a        NVARCHAR(4000)  
			,  @c_A17a        NVARCHAR(4000) 
			,  @c_A18a        NVARCHAR(4000)

			,  @c_A1LBL       NVARCHAR(4000)  
			,  @c_A2LBL       NVARCHAR(4000)  
			,  @c_A3LBL       NVARCHAR(4000)  
			,  @c_A4LBL       NVARCHAR(4000)  
			,  @c_A5LBL       NVARCHAR(4000)  
			,  @c_A6LBL       NVARCHAR(4000)  
			,  @c_A7LBL       NVARCHAR(4000)  
			,  @c_A8LBL		  NVARCHAR(4000)  
			,  @c_A9LBL       NVARCHAR(4000)  
			,  @c_A10LBL      NVARCHAR(4000)  
			,  @c_A11LBL      NVARCHAR(4000)  
			,  @c_A12LBL      NVARCHAR(4000)  
			,  @c_A13LBL      NVARCHAR(4000)  
			,  @c_A14LBL      NVARCHAR(4000)  
			,  @c_A15LBL      NVARCHAR(4000)  
			,  @c_A16LBL      NVARCHAR(4000)  
			,  @c_A17LBL      NVARCHAR(4000) 
			,  @c_A18LBL      NVARCHAR(4000)
  
	SET @c_LabelName = ''  
	SET @c_LabelValue= ''  
	SET @c_A1   = ''     
	SET @c_A2   = ''     
	SET @c_A3   = ''     
	SET @c_A4   = ''     
	SET @c_A5   = ''     
	SET @c_A6   = ''     
	SET @c_A7   = ''     
	SET @c_A8   = ''     
	SET @c_A9   = ''     
	SET @c_A10  = ''     
	SET @c_A11  = ''    
	SET @c_A12  = ''   
	SET @c_A13  = ''     
	SET @c_A14  = ''     
	SET @c_A15  = ''     
	SET @c_A16  = ''     
	SET @c_A17  = ''  

	/*WL01 Start*/
	SET @c_A1LBL   = ''     
	SET @c_A2LBL   = ''     
	SET @c_A3LBL   = ''     
	SET @c_A4LBL   = ''     
	SET @c_A5LBL   = ''     
	SET @c_A6LBL   = ''     
	SET @c_A7LBL   = ''     
	SET @c_A8LBL   = ''     
	SET @c_A9LBL   = ''     
	SET @c_A10LBL  = ''     
	SET @c_A11LBL  = ''    
	SET @c_A12LBL  = ''   
	SET @c_A13LBL  = ''     
	SET @c_A14LBL  = ''     
	SET @c_A15LBL  = ''     
	SET @c_A16LBL  = ''     
	SET @c_A17LBL  = '' 
	/*WL01 End*/	
	
	DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR  
	SELECT udf01,  
			 CL.Notes    
	FROM ORDERS OH WITH (NOLOCK)  
	JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'LUPACKLIST')   
												 --AND(CL.Storerkey = OH.Storerkey)  
												 AND(CL.UDF02 = OH.C_Country)  
									 AND(CL.UDF03 = OH.SHIPPERKEY)--WL01
	WHERE OH.Orderkey = @c_orderkey  
	ORDER BY udf01  
	OPEN CUR_LBL  
  
	FETCH NEXT FROM CUR_LBL INTO @c_LabelName  
									  ,  @c_LabelValue  
  
	WHILE @@FETCH_STATUS <> -1  
	BEGIN    
----           IF ISNULL(@c_LabelName,'') = ''
----           BEGIN 
----
----                         
----    
----
----           END

	  /*WL01 Start*/	  
		SET @c_A1LBL   =  CASE WHEN  ISNULL(@c_LabelName,'') != ''  THEN @c_LabelName ELSE @c_A1LBL  END     
		SET @c_A2LBL   =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A2LBL  END     
		SET @c_A3LBL   =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A3LBL  END     
		SET @c_A4LBL   =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A4LBL  END     
		SET @c_A5LBL   =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A5LBL  END     
		SET @c_A6LBL   =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A6LBL  END     
		SET @c_A7LBL   =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A7LBL  END     
		SET @c_A8LBL   =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A8LBL  END     
		SET @c_A9LBL   =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A9LBL END     
		SET @c_A10LBL  =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A10LBL END     
		SET @c_A11LBL  =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A11LBL END   
		SET @c_A12LBL  =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A12LBL END     
		SET @c_A13LBL  =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A13LBL END     
		SET @c_A14LBL  =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A14LBL END     
		SET @c_A15LBL  =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A15LBL END     
		SET @c_A16LBL  =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A16LBL END     
		SET @c_A17LBL  =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A17LBL END     
		SET @c_A18LBL  =  CASE WHEN  ISNULL(@c_LabelName,'') != ''   THEN @c_LabelName ELSE @c_A18LBL END  
	  /*WL01 End*/	

		SET @c_A1   =  CASE WHEN  @c_LabelName = 'A1'   THEN @c_LabelValue ELSE @c_A1  END     
		SET @c_A2   =  CASE WHEN  @c_LabelName = 'A2'   THEN @c_LabelValue ELSE @c_A2  END     
		SET @c_A3   =  CASE WHEN  @c_LabelName = 'A3'   THEN @c_LabelValue ELSE @c_A3  END     
		SET @c_A4   =  CASE WHEN  @c_LabelName = 'A4'   THEN @c_LabelValue ELSE @c_A4  END     
		SET @c_A5   =  CASE WHEN  @c_LabelName = 'A5'   THEN @c_LabelValue ELSE @c_A5  END     
		SET @c_A6   =  CASE WHEN  @c_LabelName = 'A6'   THEN @c_LabelValue ELSE @c_A6  END     
		SET @c_A7   =  CASE WHEN  @c_LabelName = 'A7'   THEN @c_LabelValue ELSE @c_A7  END     
		SET @c_A8   =  CASE WHEN  @c_LabelName = 'A8'   THEN @c_LabelValue ELSE @c_A8  END     
		SET @c_A9   =  CASE WHEN  @c_LabelName = 'A9'   THEN @c_LabelValue ELSE @c_A9  END     
		SET @c_A10  =  CASE WHEN  @c_LabelName = 'A10'  THEN @c_LabelValue ELSE @c_A10 END     
		SET @c_A11  =  CASE WHEN  @c_LabelName = 'A11'  THEN @c_LabelValue ELSE @c_A11 END   
		SET @c_A12  =  CASE WHEN  @c_LabelName = 'A12'  THEN @c_LabelValue ELSE @c_A12 END     
		SET @c_A13  =  CASE WHEN  @c_LabelName = 'A13'  THEN @c_LabelValue ELSE @c_A13 END     
		SET @c_A14  =  CASE WHEN  @c_LabelName = 'A14'  THEN @c_LabelValue ELSE @c_A14 END     
		SET @c_A15  =  CASE WHEN  @c_LabelName = 'A15'  THEN @c_LabelValue ELSE @c_A15 END     
		SET @c_A16  =  CASE WHEN  @c_LabelName = 'A16'  THEN @c_LabelValue ELSE @c_A16 END     
		SET @c_A17  =  CASE WHEN  @c_LabelName = 'A17'  THEN @c_LabelValue ELSE @c_A17 END     
		SET @c_A18  =  CASE WHEN  @c_LabelName = 'A18'  THEN @c_LabelValue ELSE @c_A18 END  
  
		  
  
	FETCH NEXT FROM CUR_LBL INTO @c_LabelName  
									  ,  @c_LabelValue  
	END  
	CLOSE CUR_LBL  
	DEALLOCATE CUR_LBL  

		 IF ((@c_A1 = '' AND @C_A1LBL = '') OR (@c_A2 = '' AND @C_A2LBL = '') OR (@c_A3 = '' AND @C_A3LBL = '') 
			OR (@c_A4 = '' AND @C_A4LBL = '') OR (@c_A5 = '' AND @C_A5LBL = '') OR (@c_A6 = '' AND @C_A6LBL = '')
			OR (@c_A7 = '' AND @C_A7LBL = '') OR (@c_A8 = '' AND @C_A8LBL = '') OR (@c_A9 = '' AND @C_A9LBL = '')
			OR (@c_A10 = '' AND @C_A10LBL = '') OR (@c_A11 = '' AND @C_A11LBL = '') OR (@c_A12 = '' AND @C_A12LBL = '')
			OR (@c_A13 = '' AND @C_A13LBL = '') OR (@c_A14 = '' AND @C_A14LBL = '') OR (@c_A15 = '' AND @C_A15LBL = '')
			OR (@c_A16 = '' AND @C_A16LBL = '') OR (@c_A17 = '' AND @C_A17LBL = '') OR (@c_A18 = '' AND @C_A18LBL = ''))
		 BEGIN
			SELECT TOP 1 @c_A1a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A1' AND C.UDF02 ='SD'     
			SELECT TOP 1 @c_A2a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A2' AND C.UDF02 ='SD'          
			SELECT TOP 1 @c_A3a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A3' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A4a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A4' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A5a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A5' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A6a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A6' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A7a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A7' AND C.UDF02 ='SD'             
			SELECT TOP 1 @c_A8a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A8' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A9a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A9' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A10a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A10' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A11a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A11' AND C.UDF02 ='SD'              
			SELECT TOP 1 @c_A12a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A12' AND C.UDF02 ='SD'             
			SELECT TOP 1 @c_A13a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A13' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A14a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A14' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A15a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A15' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A16a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A16' AND C.UDF02 ='SD'               
			SELECT TOP 1 @c_A17a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A17' AND C.UDF02 ='SD'           
			SELECT TOP 1 @c_A18a = C.Notes FROM CODELKUP C WITH (NOLOCK) WHERE C.Listname='LUPACKLIST' AND C.UDF01 ='A18' AND C.UDF02 ='SD'
			
	
  END


  
	INSERT INTO @RetPackList18Lbl  
	  ( Orderkey         
			,  A1               
			,  A2               
			,  A3               
			,  A4              
			,  A5              
			,  A6              
			,  A7               
			,  A8               
			,  A9               
			,  A10               
			,  A11  
			,  A12               
			,  A13              
			,  A14              
			,  A15              
			,  A16              
			,  A17              
			,  A18           
						 
			)  
	SELECT @c_Orderkey  
			,  CASE WHEN ISNULL(@c_A1,'') <> '' THEN  ISNULL(@c_A1,'') ELSE ISNULL(@c_A1A,'') END  
			,  CASE WHEN ISNULL(@c_A2,'') <> '' THEN  ISNULL(@c_A2,'') ELSE ISNULL(@c_A2A,'') END       
			,  CASE WHEN ISNULL(@c_A3,'') <> '' THEN  ISNULL(@c_A3,'') ELSE ISNULL(@c_A3A,'') END       
			,  CASE WHEN ISNULL(@c_A4,'') <> '' THEN  ISNULL(@c_A4,'') ELSE ISNULL(@c_A4A,'') END      
			,  CASE WHEN ISNULL(@c_A5,'') <> '' THEN  ISNULL(@c_A5,'') ELSE ISNULL(@c_A5A,'') END      
			,  CASE WHEN ISNULL(@c_A6,'') <> '' THEN  ISNULL(@c_A6,'') ELSE ISNULL(@c_A6A,'')END      
			,  CASE WHEN ISNULL(@c_A7,'') <> '' THEN  ISNULL(@c_A7,'') ELSE ISNULL(@c_A7A,'') END       
			,  CASE WHEN ISNULL(@c_A8,'') <> '' THEN  ISNULL(@c_A8,'') ELSE ISNULL(@c_A8A,'') END       
			,  CASE WHEN ISNULL(@c_A9,'') <> '' THEN  ISNULL(@c_A9,'') ELSE ISNULL(@c_A9A,'') END       
			,  CASE WHEN ISNULL(@c_A10,'') <> '' THEN ISNULL(@c_A10,'') ELSE ISNULL(@c_A10A,'') END       
			,  CASE WHEN ISNULL(@c_A11,'') <> '' THEN ISNULL(@c_A11,'') ELSE ISNULL(@c_A11A,'') END   
			,  CASE WHEN ISNULL(@c_A12,'') <> '' THEN  ISNULL(@c_A12,'') ELSE ISNULL(@c_A12A,'') END        
			,  CASE WHEN ISNULL(@c_A13,'') <> '' THEN  ISNULL(@c_A13,'') ELSE ISNULL(@c_A13A,'') END      
			,  CASE WHEN ISNULL(@c_A14,'') <> '' THEN  ISNULL(@c_A14,'') ELSE ISNULL(@c_A14A,'') END      
			,  CASE WHEN ISNULL(@c_A15,'') <> '' THEN  ISNULL(@c_A15,'') ELSE ISNULL(@c_A15A,'') END      
			,  CASE WHEN ISNULL(@c_A16,'') <> '' THEN  ISNULL(@c_A16,'') ELSE ISNULL(@c_A16A,'') END      
			,  CASE WHEN ISNULL(@c_A17,'') <> '' THEN  ISNULL(@c_A17,'') ELSE ISNULL(@c_A17A,'') END      
			,  CASE WHEN ISNULL(@c_A18,'') <> '' THEN  @c_A18 ELSE @c_A18a END      
			 
  
  
	RETURN  
END 

GO