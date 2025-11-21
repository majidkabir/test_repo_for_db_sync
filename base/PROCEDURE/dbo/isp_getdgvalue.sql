SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetDGValue                                     */
/* Creation Date: Jun-2011                                              */
/* Copyright: IDS                                                       */
/* Written by: SHONG                                                    */
/*                                                                      */
/* Purpose: SOS#218979                                                  */
/*                                                                      */
/* Called By: w_populate_load.wf_dg_process function                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author         Purposes                                  */
/* 18-Jul-2011 YTWan          Convert BUSR6 to Float. (Wan01)           */
/************************************************************************/

CREATE PROC [dbo].[isp_GetDGValue] 
(@cOrderKey    NVARCHAR(10),
 @nDGValue01   FLOAT OUTPUT, 
 @nDGValue02   FLOAT OUTPUT, 
 @nDGValue03   FLOAT OUTPUT, 
 @nDGValue04   FLOAT OUTPUT, 
 @nDGValue05   FLOAT OUTPUT, 
 @nDGValue06   FLOAT OUTPUT, 
 @nDGValue07   FLOAT OUTPUT, 
 @nDGValue08   FLOAT OUTPUT, 
 @nDGValue09   FLOAT OUTPUT, 
 @nDGValue10   FLOAT OUTPUT        
)
AS
BEGIN
   DECLARE 
    @cDGCode    NVARCHAR(20)
   ,@cUDFColumn NVARCHAR(30)
   ,@cSQLSelect nVARCHAR(MAX)
   ,@cSQLParm   nVARCHAR(MAX)
   ,@cUDFCol01  NVARCHAR(30)  
   ,@cUDFCol02  NVARCHAR(30)  
   ,@cUDFCol03  NVARCHAR(30)  
   ,@cUDFCol04  NVARCHAR(30)  
   ,@cUDFCol05  NVARCHAR(30)  
   ,@cUDFCol06  NVARCHAR(30)  
   ,@cUDFCol07  NVARCHAR(30)  
   ,@cUDFCol08  NVARCHAR(30)  
   ,@cUDFCol09  NVARCHAR(30)  
   ,@cUDFCol10  NVARCHAR(30)  

   SET @cSQLSelect = ''
   SET @cSQLParm   = ''

   SET @nDGValue01 = 0
   SET @nDGValue02 = 0
   SET @nDGValue03 = 0
   SET @nDGValue04 = 0
   SET @nDGValue05 = 0
   SET @nDGValue06 = 0
   SET @nDGValue07 = 0
   SET @nDGValue08 = 0
   SET @nDGValue09 = 0
   SET @nDGValue10 = 0

   DECLARE C_DGSetup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT CODE, SHORT 
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  LISTNAME = 'VHCUDFDGCD' 
   
   OPEN C_DGSetup 

   FETCH NEXT FROM C_DGSetup INTO @cUDFColumn, @cDGCode
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @cUDFColumn = 'USERDEFINE01' SET @cUDFCol01 = @cDGCode  
      IF @cUDFColumn = 'USERDEFINE02' SET @cUDFCol02 = @cDGCOde  
      IF @cUDFColumn = 'USERDEFINE03' SET @cUDFCol03 = @cDGCOde              
      IF @cUDFColumn = 'USERDEFINE04' SET @cUDFCol04 = @cDGCOde              
      IF @cUDFColumn = 'USERDEFINE05' SET @cUDFCol05 = @cDGCOde              
      IF @cUDFColumn = 'USERDEFINE06' SET @cUDFCol06 = @cDGCOde              
      IF @cUDFColumn = 'USERDEFINE07' SET @cUDFCol07 = @cDGCOde              
      IF @cUDFColumn = 'USERDEFINE08' SET @cUDFCol08 = @cDGCOde              
      IF @cUDFColumn = 'USERDEFINE09' SET @cUDFCol09 = @cDGCOde              
      IF @cUDFColumn = 'USERDEFINE10' SET @cUDFCol10 = @cDGCOde

      FETCH NEXT FROM C_DGSetup INTO @cUDFColumn, @cDGCode
   END 
   CLOSE C_DGSetup
   DEALLOCATE C_DGSetup

   SELECT 
   --(Wan01) - START Convert BUSR6 to flaot and check if UDFCol <> ''
    @nDGValue01 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol01 AND LEN(@cUDFCol01) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END),
    @nDGValue02 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol02 AND LEN(@cUDFCol02) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END),
    @nDGValue03 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol03 AND LEN(@cUDFCol03) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END),
    @nDGValue04 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol04 AND LEN(@cUDFCol04) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END),
    @nDGValue05 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol05 AND LEN(@cUDFCol05) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END),
    @nDGValue06 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol06 AND LEN(@cUDFCol06) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END),
    @nDGValue07 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol07 AND LEN(@cUDFCol07) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END),
    @nDGValue08 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol08 AND LEN(@cUDFCol08) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END),
    @nDGValue09 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol09 AND LEN(@cUDFCol09) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END),
    @nDGValue10 = SUM(CASE WHEN SKU.HazardousFlag = @cUDFCol10 AND LEN(@cUDFCol10) > 0 THEN (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) ELSE 0 END * CASE WHEN ISNUMERIC(SKU.BUSR6)=1 THEN CONVERT(FLOAT,SKU.BUSR6) ELSE 0 END)
   --(Wan01) - END Convert BUSR6 to flaot
   FROM ORDERDETAIL OD WITH (NOLOCK)
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU 
   WHERE OD.OrderKey = @cOrderKey


   -- Convert to Litre   
   SET @nDGValue01 = CASE WHEN @nDGValue01 > 0 THEN @nDGValue01 * 0.001 ELSE 0 END
   SET @nDGValue02 = CASE WHEN @nDGValue02 > 0 THEN @nDGValue02 * 0.001 ELSE 0 END
   SET @nDGValue03 = CASE WHEN @nDGValue03 > 0 THEN @nDGValue03 * 0.001 ELSE 0 END
   SET @nDGValue04 = CASE WHEN @nDGValue04 > 0 THEN @nDGValue04 * 0.001 ELSE 0 END
   SET @nDGValue05 = CASE WHEN @nDGValue05 > 0 THEN @nDGValue05 * 0.001 ELSE 0 END
   SET @nDGValue06 = CASE WHEN @nDGValue06 > 0 THEN @nDGValue06 * 0.001 ELSE 0 END
   SET @nDGValue07 = CASE WHEN @nDGValue07 > 0 THEN @nDGValue07 * 0.001 ELSE 0 END
   SET @nDGValue08 = CASE WHEN @nDGValue08 > 0 THEN @nDGValue08 * 0.001 ELSE 0 END
   SET @nDGValue09 = CASE WHEN @nDGValue09 > 0 THEN @nDGValue09 * 0.001 ELSE 0 END
   SET @nDGValue10 = CASE WHEN @nDGValue10 > 0 THEN @nDGValue10 * 0.001 ELSE 0 END

END

GO