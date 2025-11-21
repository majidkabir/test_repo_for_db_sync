SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_LoadDGSummaryRpt                               */
/* Creation Date: Oct-2011                                              */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#218979                                                  */
/*                                                                      */
/* Called By: r_dw_loadplan_sheet01_01                                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author         Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_LoadDGSummaryRpt] 
(@c_LoadKey    NVARCHAR(10))
AS
BEGIN

   DECLARE 
    @b_success    INT
   ,@n_Err        INT
   ,@c_ErrMsg     NVARCHAR(255)
   ,@c_Facility   NVARCHAR(5)
   ,@c_DGHandling NVARCHAR(1)

   ,@c_DGCode    NVARCHAR(20)
   ,@c_UDFColumn NVARCHAR(30)
   ,@c_SQLSelect	nVARCHAR(MAX)
   ,@c_SQLParm  	nVARCHAR(MAX)
   
   ,@n_SkuCntDG01	INT
	,@n_SkuCntDG02	INT
	,@n_SkuCntDG03	INT
	,@n_SkuCntDG04	INT
	,@n_SkuCntDG05	INT
	,@n_SkuCntDG06	INT
	,@n_SkuCntDG07	INT
	,@n_SkuCntDG08	INT
	,@n_SkuCntDG09	INT
	,@n_SkuCntDG10	INT

   ,@n_DGLimit01	FLOAT
	,@n_DGLimit02	FLOAT
	,@n_DGLimit03	FLOAT
	,@n_DGLimit04	FLOAT
	,@n_DGLimit05	FLOAT
	,@n_DGLimit06	FLOAT
	,@n_DGLimit07	FLOAT
	,@n_DGLimit08	FLOAT
	,@n_DGLimit09	FLOAT
	,@n_DGLimit10	FLOAT
	
	,@n_DGValue01	FLOAT
	,@n_DGValue02	FLOAT
	,@n_DGValue03	FLOAT
	,@n_DGValue04	FLOAT
	,@n_DGValue05	FLOAT
	,@n_DGValue06	FLOAT
	,@n_DGValue07	FLOAT
	,@n_DGValue08	FLOAT
	,@n_DGValue09	FLOAT
	,@n_DGValue10	FLOAT


   ,@c_UDFCol01  NVARCHAR(30)  
   ,@c_UDFCol02  NVARCHAR(30)  
   ,@c_UDFCol03  NVARCHAR(30)  
   ,@c_UDFCol04  NVARCHAR(30)  
   ,@c_UDFCol05  NVARCHAR(30)  
   ,@c_UDFCol06  NVARCHAR(30)  
   ,@c_UDFCol07  NVARCHAR(30)  
   ,@c_UDFCol08  NVARCHAR(30)  
   ,@c_UDFCol09  NVARCHAR(30)  
   ,@c_UDFCol10  NVARCHAR(30)
   
   ,@c_DGLimit01  NVARCHAR(30)
	,@c_DGLimit02  NVARCHAR(30)
	,@c_DGLimit03  NVARCHAR(30)
	,@c_DGLimit04  NVARCHAR(30)
	,@c_DGLimit05  NVARCHAR(30)
	,@c_DGLimit06  NVARCHAR(30)
	,@c_DGLimit07  NVARCHAR(30)
	,@c_DGLimit08  NVARCHAR(30)
	,@c_DGLimit09  NVARCHAR(30)
	,@c_DGLimit10  NVARCHAR(30)
  
   
   SET @c_SQLSelect 	= ''
   SET @c_SQLParm   	= ''   
   
   SET @n_DGLimit01	= 0.00	
	SET @n_DGLimit02	= 0.00	
	SET @n_DGLimit03	= 0.00	
	SET @n_DGLimit04	= 0.00	
	SET @n_DGLimit05	= 0.00	
	SET @n_DGLimit06	= 0.00	
	SET @n_DGLimit07	= 0.00	
	SET @n_DGLimit08	= 0.00	
	SET @n_DGLimit09	= 0.00	
	SET @n_DGLimit10	= 0.00	
                   	
   SET @n_DGValue01 	= 0.00
   SET @n_DGValue02 	= 0.00
   SET @n_DGValue03 	= 0.00
   SET @n_DGValue04 	= 0.00
   SET @n_DGValue05 	= 0.00
   SET @n_DGValue06 	= 0.00
   SET @n_DGValue07 	= 0.00
   SET @n_DGValue08 	= 0.00
   SET @n_DGValue09 	= 0.00
   SET @n_DGValue10 	= 0.00


   SET @c_DGLimit01 	= ''  
   SET @c_DGLimit02 	= ''  
   SET @c_DGLimit03 	= ''              
   SET @c_DGLimit04 	= ''              
   SET @c_DGLimit05 	= ''              
   SET @c_DGLimit06 	= ''              
   SET @c_DGLimit07 	= ''              
   SET @c_DGLimit08 	= ''              
   SET @c_DGLimit09 	= ''              
   SET @c_DGLimit10 	= ''

   SELECT @c_Facility = ISNULL(RTRIM(Facility),'')
   FROM LoadPlan WITH (NOLOCK)
   WHERE LoadKey = @c_LoadKey

   EXEC nspgetright @c_Facility, '','', 'LoadPlanDGHandling', @b_success OUTPUT, @c_DGHandling OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT

   IF @c_DGHandling <> '1' GOTO QUIT

   DECLARE C_DGSetup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT CODE, SHORT 
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  LISTNAME = 'VHCUDFDGCD' 
   
   OPEN C_DGSetup 

   FETCH NEXT FROM C_DGSetup INTO @c_UDFColumn, @c_DGCode
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_UDFColumn = 'USERDEFINE01' SET @c_UDFCol01 = @c_DGCode  
      IF @c_UDFColumn = 'USERDEFINE02' SET @c_UDFCol02 = @c_DGCOde  
      IF @c_UDFColumn = 'USERDEFINE03' SET @c_UDFCol03 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE04' SET @c_UDFCol04 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE05' SET @c_UDFCol05 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE06' SET @c_UDFCol06 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE07' SET @c_UDFCol07 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE08' SET @c_UDFCol08 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE09' SET @c_UDFCol09 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE10' SET @c_UDFCol10 = @c_DGCOde

      FETCH NEXT FROM C_DGSetup INTO @c_UDFColumn, @c_DGCode
   END 
   CLOSE C_DGSetup
   DEALLOCATE C_DGSetup

   SELECT TOP 1  
           @c_DGLimit01 = REPLACE(ISNULL(RTRIM(V.UserDefine01),''),' ','')
         , @c_DGLimit02 = REPLACE(ISNULL(RTRIM(V.UserDefine02),''),' ','')
         , @c_DGLimit03 = REPLACE(ISNULL(RTRIM(V.UserDefine03),''),' ','')
         , @c_DGLimit04 = REPLACE(ISNULL(RTRIM(V.UserDefine04),''),' ','')
         , @c_DGLimit05 = REPLACE(ISNULL(RTRIM(V.UserDefine05),''),' ','')
         , @c_DGLimit06 = REPLACE(ISNULL(RTRIM(V.UserDefine06),''),' ','')
         , @c_DGLimit07 = REPLACE(ISNULL(RTRIM(V.UserDefine07),''),' ','')
         , @c_DGLimit08 = REPLACE(ISNULL(RTRIM(V.UserDefine08),''),' ','')
         , @c_DGLimit09 = REPLACE(ISNULL(RTRIM(V.UserDefine09),''),' ','')
         , @c_DGLimit10 = REPLACE(ISNULL(RTRIM(V.UserDefine10),''),' ','')
   FROM IDS_LP_Vehicle LPV WITH (NOLOCK) 
   JOIN IDS_Vehicle V WITH (NOLOCK) ON (V.VehicleNumber = LPV.VehicleNumber) 
   WHERE LPV.loadkey = @c_Loadkey

   SELECT 
     @n_DGValue01 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol01 AND LEN(@c_UDFCol01) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
    ,@n_DGValue02 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol02 AND LEN(@c_UDFCol02) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
    ,@n_DGValue03 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol03 AND LEN(@c_UDFCol03) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
    ,@n_DGValue04 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol04 AND LEN(@c_UDFCol04) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
    ,@n_DGValue05 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol05 AND LEN(@c_UDFCol05) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
    ,@n_DGValue06 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol06 AND LEN(@c_UDFCol06) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
    ,@n_DGValue07 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol07 AND LEN(@c_UDFCol07) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
    ,@n_DGValue08 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol08 AND LEN(@c_UDFCol08) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
    ,@n_DGValue09 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol09 AND LEN(@c_UDFCol09) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
    ,@n_DGValue10 = SUM(CASE WHEN SKU.HazardousFlag = @c_UDFCol10 AND LEN(@c_UDFCol10) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
   FROM LoadPlanDetail LPD WITH (NOLOCK)
   JOIN OrderDetail OD WITH (NOLOCK) ON (OD.Orderkey = LPD.Orderkey) 
   JOIN Sku WITH (NOLOCK) ON (Sku.StorerKey = OD.StorerKey) AND (Sku.SKU = OD.SKU) 
   WHERE LPD.LoadKey = @c_LoadKey

   SELECT 
     @n_SkuCntDG01= CASE WHEN SKU.HazardousFlag = @c_UDFCol01 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END
    ,@n_SkuCntDG02= CASE WHEN SKU.HazardousFlag = @c_UDFCol02 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END  
    ,@n_SkuCntDG03= CASE WHEN SKU.HazardousFlag = @c_UDFCol03 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END
    ,@n_SkuCntDG04= CASE WHEN SKU.HazardousFlag = @c_UDFCol04 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END
    ,@n_SkuCntDG05= CASE WHEN SKU.HazardousFlag = @c_UDFCol05 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END
    ,@n_SkuCntDG06= CASE WHEN SKU.HazardousFlag = @c_UDFCol06 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END
    ,@n_SkuCntDG07= CASE WHEN SKU.HazardousFlag = @c_UDFCol07 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END
    ,@n_SkuCntDG08= CASE WHEN SKU.HazardousFlag = @c_UDFCol08 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END
    ,@n_SkuCntDG09= CASE WHEN SKU.HazardousFlag = @c_UDFCol09 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END
    ,@n_SkuCntDG10= CASE WHEN SKU.HazardousFlag = @c_UDFCol10 THEN COUNT(DISTINCT OD.SKU) ELSE 0 END
   FROM LoadPlanDetail LPD WITH (NOLOCK)
   JOIN OrderDetail OD WITH (NOLOCK) ON (OD.Orderkey = LPD.Orderkey) 
   JOIN Sku WITH (NOLOCK) ON (Sku.StorerKey = OD.StorerKey) AND (Sku.SKU = OD.SKU) 
   WHERE LPD.LoadKey = @c_LoadKey
   GROUP BY SKU.HazardousFlag 
    
     
   SET @n_DGLimit01 = CASE CHARINDEX('/',@c_DGLimit01) WHEN 0 THEN @c_DGLimit01 
                      ELSE CASE WHEN @n_SkuCntDG01 <= 1 THEN LEFT(@c_DGLimit01,CHARINDEX('/',@c_DGLimit01)-1) ELSE RIGHT(@c_DGLimit01,LEN(@c_DGLimit01)-CHARINDEX('/',@c_DGLimit01)) END END
   SET @n_DGLimit02 = CASE CHARINDEX('/',@c_DGLimit02) WHEN 0 THEN @c_DGLimit02 
   						 ELSE CASE WHEN @n_SkuCntDG02 <= 1 THEN LEFT(@c_DGLimit02,CHARINDEX('/',@c_DGLimit02)-1) ELSE RIGHT(@c_DGLimit02,LEN(@c_DGLimit02)-CHARINDEX('/',@c_DGLimit02)) END END
   SET @n_DGLimit03 = CASE CHARINDEX('/',@c_DGLimit03) WHEN 0 THEN @c_DGLimit03 
   					    ELSE CASE WHEN @n_SkuCntDG03 <= 1 THEN LEFT(@c_DGLimit03,CHARINDEX('/',@c_DGLimit03)-1) ELSE RIGHT(@c_DGLimit03,LEN(@c_DGLimit03)-CHARINDEX('/',@c_DGLimit03)) END END
   SET @n_DGLimit04 = CASE CHARINDEX('/',@c_DGLimit04) WHEN 0 THEN @c_DGLimit04 
   						 ELSE CASE WHEN @n_SkuCntDG04 <= 1 THEN LEFT(@c_DGLimit04,CHARINDEX('/',@c_DGLimit04)-1) ELSE RIGHT(@c_DGLimit04,LEN(@c_DGLimit04)-CHARINDEX('/',@c_DGLimit04)) END END
   SET @n_DGLimit05 = CASE CHARINDEX('/',@c_DGLimit05) WHEN 0 THEN @c_DGLimit05 
   						 ELSE CASE WHEN @n_SkuCntDG05 <= 1 THEN LEFT(@c_DGLimit05,CHARINDEX('/',@c_DGLimit05)-1) ELSE RIGHT(@c_DGLimit05,LEN(@c_DGLimit05)-CHARINDEX('/',@c_DGLimit05)) END END
   SET @n_DGLimit06 = CASE CHARINDEX('/',@c_DGLimit06) WHEN 0 THEN @c_DGLimit06 
   						 ELSE CASE WHEN @n_SkuCntDG06 <= 1 THEN LEFT(@c_DGLimit06,CHARINDEX('/',@c_DGLimit06)-1) ELSE RIGHT(@c_DGLimit06,LEN(@c_DGLimit06)-CHARINDEX('/',@c_DGLimit06)) END END
   SET @n_DGLimit07 = CASE CHARINDEX('/',@c_DGLimit07) WHEN 0 THEN @c_DGLimit07 
   						 ELSE CASE WHEN @n_SkuCntDG07 <= 1 THEN LEFT(@c_DGLimit07,CHARINDEX('/',@c_DGLimit07)-1) ELSE RIGHT(@c_DGLimit07,LEN(@c_DGLimit07)-CHARINDEX('/',@c_DGLimit07)) END END
   SET @n_DGLimit08 = CASE CHARINDEX('/',@c_DGLimit08) WHEN 0 THEN @c_DGLimit08 
   						 ELSE CASE WHEN @n_SkuCntDG08 <= 1 THEN LEFT(@c_DGLimit08,CHARINDEX('/',@c_DGLimit08)-1) ELSE RIGHT(@c_DGLimit08,LEN(@c_DGLimit08)-CHARINDEX('/',@c_DGLimit08)) END END
   SET @n_DGLimit09 = CASE CHARINDEX('/',@c_DGLimit09) WHEN 0 THEN @c_DGLimit09 
   					    ELSE CASE WHEN @n_SkuCntDG09 <= 1 THEN LEFT(@c_DGLimit09,CHARINDEX('/',@c_DGLimit09)-1) ELSE RIGHT(@c_DGLimit09,LEN(@c_DGLimit09)-CHARINDEX('/',@c_DGLimit09)) END END
   SET @n_DGLimit10 = CASE CHARINDEX('/',@c_DGLimit10) WHEN 0 THEN @c_DGLimit10 
   						 ELSE CASE WHEN @n_SkuCntDG10 <= 1 THEN LEFT(@c_DGLimit10,CHARINDEX('/',@c_DGLimit10)-1) ELSE RIGHT(@c_DGLimit10,LEN(@c_DGLimit10)-CHARINDEX('/',@c_DGLimit10)) END END
    

   IF @c_UDFCol01 = '' OR @c_DGLimit01 = '' SET @c_UDFCol01 = 'UserDefine01'
   IF @c_UDFCol02 = '' OR @c_DGLimit02 = '' SET @c_UDFCol02 = 'UserDefine02'
   IF @c_UDFCol03 = '' OR @c_DGLimit03 = '' SET @c_UDFCol03 = 'UserDefine03'
   IF @c_UDFCol04 = '' OR @c_DGLimit04 = '' SET @c_UDFCol04 = 'UserDefine04'
   IF @c_UDFCol05 = '' OR @c_DGLimit05 = '' SET @c_UDFCol05 = 'UserDefine05'
   IF @c_UDFCol06 = '' OR @c_DGLimit06 = '' SET @c_UDFCol06 = 'UserDefine06'
   IF @c_UDFCol07 = '' OR @c_DGLimit07 = '' SET @c_UDFCol07 = 'UserDefine07'
   IF @c_UDFCol08 = '' OR @c_DGLimit08 = '' SET @c_UDFCol08 = 'UserDefine08'
   IF @c_UDFCol09 = '' OR @c_DGLimit09 = '' SET @c_UDFCol09 = 'UserDefine09'
   IF @c_UDFCol10 = '' OR @c_DGLimit10 = '' SET @c_UDFCol10 = 'UserDefine10'

   IF @c_DGLimit01 = '' SET @c_DGLimit01 = '0'
   IF @c_DGLimit02 = '' SET @c_DGLimit02 = '0'
   IF @c_DGLimit03 = '' SET @c_DGLimit03 = '0'
   IF @c_DGLimit04 = '' SET @c_DGLimit04 = '0'
   IF @c_DGLimit05 = '' SET @c_DGLimit05 = '0'
   IF @c_DGLimit06 = '' SET @c_DGLimit06 = '0'
   IF @c_DGLimit07 = '' SET @c_DGLimit07 = '0'
   IF @c_DGLimit08 = '' SET @c_DGLimit08 = '0'
   IF @c_DGLimit09 = '' SET @c_DGLimit09 = '0'
   IF @c_DGLimit10 = '' SET @c_DGLimit10 = '0'

   -- Convert to Litre   
   SET @n_DGValue01 = CASE WHEN @n_DGValue01 > 0 THEN @n_DGValue01 * 0.001 ELSE 0 END
   SET @n_DGValue02 = CASE WHEN @n_DGValue02 > 0 THEN @n_DGValue02 * 0.001 ELSE 0 END
   SET @n_DGValue03 = CASE WHEN @n_DGValue03 > 0 THEN @n_DGValue03 * 0.001 ELSE 0 END
   SET @n_DGValue04 = CASE WHEN @n_DGValue04 > 0 THEN @n_DGValue04 * 0.001 ELSE 0 END
   SET @n_DGValue05 = CASE WHEN @n_DGValue05 > 0 THEN @n_DGValue05 * 0.001 ELSE 0 END
   SET @n_DGValue06 = CASE WHEN @n_DGValue06 > 0 THEN @n_DGValue06 * 0.001 ELSE 0 END
   SET @n_DGValue07 = CASE WHEN @n_DGValue07 > 0 THEN @n_DGValue07 * 0.001 ELSE 0 END
   SET @n_DGValue08 = CASE WHEN @n_DGValue08 > 0 THEN @n_DGValue08 * 0.001 ELSE 0 END
   SET @n_DGValue09 = CASE WHEN @n_DGValue09 > 0 THEN @n_DGValue09 * 0.001 ELSE 0 END
   SET @n_DGValue10 = CASE WHEN @n_DGValue10 > 0 THEN @n_DGValue10 * 0.001 ELSE 0 END
            
   QUIT:
   SELECT @c_UDFCol01	,@c_UDFCol02	,@c_UDFCol03	,@c_UDFCol04	,@c_UDFCol05	,@c_UDFCol06	,@c_UDFCol07	,@c_UDFCol08	,@c_UDFCol09	,@c_UDFCol10
			,@c_DGLimit01	,@c_DGLimit02	,@c_DGLimit03	,@c_DGLimit04	,@c_DGLimit05	,@c_DGLimit06	,@c_DGLimit07	,@c_DGLimit08	,@c_DGLimit09	,@c_DGLimit10
			,@n_DGLimit01	,@n_DGLimit02	,@n_DGLimit03	,@n_DGLimit04	,@n_DGLimit05	,@n_DGLimit06	,@n_DGLimit07	,@n_DGLimit08	,@n_DGLimit09	,@n_DGLimit10
			,@n_DGValue01	,@n_DGValue02	,@n_DGValue03	,@n_DGValue04	,@n_DGValue05	,@n_DGValue06	,@n_DGValue07	,@n_DGValue08	,@n_DGValue09	,@n_DGValue10 

END

GO