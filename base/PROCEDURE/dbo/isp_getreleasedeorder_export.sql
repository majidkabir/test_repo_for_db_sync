SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetReleasedEOrder_Export                            */
/* Creation Date: 08-Aug-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-9640 - ECOM get released EOrder for Export              */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetReleasedEOrder_Export]  
           @c_Storerkey        NVARCHAR(15)
         , @c_Facility         NVARCHAR(5)
         , @c_ReleaseGroup     NVARCHAR(30)  --BuildParmGroup
         , @c_BuildParmCode    NVARCHAR(10)         
         , @dt_StartDate       DATETIME = NULL
         , @dt_EndDate         DATETIME = NULL
         , @c_DateMode         NVARCHAR(10)
         , @c_UsrStorerkey     NVARCHAR(250)
         , @c_Loadkey          NVARCHAR(MAX) = ''  --multi loadkey delimited by comma
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT            
         , @c_SQL             NVARCHAR(MAX) 
         , @c_SQLParms        NVARCHAR(MAX)            
         , @c_UserName        NVARCHAR(20)
         , @b_SingleStorer    BIT          
         , @n_BatchNo         BIGINT
          
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @c_UserName = SUSER_SNAME()
   SET @b_SingleStorer = 0
   SET @n_BatchNo = 0
   
   CREATE TABLE #LOAD (Loadkey NVARCHAR(10) NULL)
   
   IF @c_UsrStorerkey <> '' AND CHARINDEX(',', @c_UsrStorerkey) > 0
   BEGIN
      SET @b_SingleStorer = 0
   END

   IF ISNULL(@c_Loadkey,'') <> ''
   BEGIN
   	  INSERT INTO #LOAD
      SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_Loadkey)
   END
   ELSE
   BEGIN
      SET @c_SQL = N'SELECT TOP 1 @n_BatchNo = BL.BatchNo'
                 + ' FROM BUILDLOADLOG       BL  WITH (NOLOCK)'
                 + ' JOIN BUILDLOADDETAILLOG BLD WITH (NOLOCK) ON (BL.BatchNo = BLD.BatchNo)'
                 + ' JOIN LOADPLANDETAIL     LP  WITH (NOLOCK) ON (BLD.Loadkey= LP.Loadkey)' 
                 + ' WHERE BL.BuildParmGroup = @c_ReleaseGroup '  
                 + ' AND BL.BuildParmCode = @c_BuildParmCode' 
                 + ' AND BL.Storerkey = @c_Storerkey' 
                 + CASE WHEN @c_UsrStorerkey = '' AND @c_Storerkey <> '' 
                        THEN ' AND BLD.AddWho = @c_UserName'     
                        WHEN @c_UsrStorerkey <>'' AND @b_SingleStorer = 1
                        THEN ' AND BL.Storerkey = @c_UsrStorerkey'  
                        WHEN @c_UsrStorerkey <>'' AND @b_SingleStorer = 0
                        THEN ' AND BL.Storerkey IN (''' + REPLACE(@c_UsrStorerkey, ',', ''',''') + ''')'  
                        ELSE ''
                        END
                 + CASE WHEN @c_Facility  = '' 
                        THEN '' 
                        ELSE ' AND BL.Facility = @c_Facility'     
                        END
                 + ' AND   EXISTS ( SELECT 1' 
                 +               '  FROM ORDERS OH WITH (NOLOCK)'
                 +               '  WHERE OH.Orderkey = LP.Orderkey'  
                 +     CASE WHEN @c_DateMode = '1'
                            THEN ' AND  OH.AddDate   BETWEEN @dt_StartDate AND @dt_EndDate '
                            ELSE ' AND  OH.OrderDate BETWEEN @dt_StartDate AND @dt_EndDate ' 
                            END
                 +               ' )'
                 + ' ORDER BY BL.BatchNo DESC'
            
      SET @c_SQLParms = N'@c_Storerkey       NVARCHAR(15)'
                      + ',@c_Facility        NVARCHAR(5)'
                      + ',@c_ReleaseGroup    NVARCHAR(30)'
                      + ',@c_BuildParmCode   NVARCHAR(10)'                   
                      + ',@dt_StartDate      DATETIME'
                      + ',@dt_EndDate        DATETIME'
                      + ',@c_UserName        NVARCHAR(20)'
                      + ',@c_UsrStorerkey    NVARCHAR(250)'
                      + ',@n_BatchNo         BIGINT OUTPUT'
                      + ',@c_Loadkey         NVARCHAR(MAX)'
      
      EXECUTE sp_ExecuteSQL  @c_SQL
                           , @c_SQLParms
                           , @c_Storerkey
                           , @c_Facility
                           , @c_ReleaseGroup 
                           , @c_BuildParmCode
                           , @dt_StartDate
                           , @dt_EndDate
                           , @c_UserName
                           , @c_UsrStorerkey
                           , @n_BatchNo OUTPUT
                           , @c_Loadkey
       
       INSERT INTO #LOAD
       SELECT BLD.Loadkey
       FROM BUILDLOADLOG BL (NOLOCK)
       JOIN BUILDLOADDETAILLOG BLD (NOLOCK) ON BL.BatchNo = BLD.BatchNo
       WHERE BL.BatchNo = @n_BatchNo              
   END                        

   SELECT ROW_NUMBER() OVER(ORDER BY O.Storerkey, LPD.Loadkey, O.Orderkey, OD.Sku) AS RowNo,
          LPD.Loadkey,
          O.Orderkey, 
          OD.Sku,
          SKU.AltSku AS UPC,
          SUM(OD.OpenQty) AS Qty,
          O.C_Contact1,
          O.C_Zip,
          O.C_City,
          O.C_Address2,
          O.C_Phone1,
          O.TrackingNo,
          O.ShipperKey,
          O.DeliveryPlace AS Destination,
          CASE WHEN LTRIM(ISNULL(O.DeliveryNote,'')) = '10' THEN '10' ELSE '' END,     
          O.Storerkey    
   FROM BUILDLOADLOG BL (NOLOCK)
   JOIN BUILDLOADDETAILLOG BLD (NOLOCK) ON BL.BatchNo = BLD.BatchNo
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON BLD.Loadkey = LPD.Loadkey
   JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
   JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
   WHERE BLD.Loadkey IN (SELECT Loadkey FROM #LOAD)
   --WHERE BL.BatchNo = @n_BatchNo
   GROUP BY O.Orderkey, 
            LPD.Loadkey,
            OD.Sku,
            SKU.AltSku,            
            O.C_Contact1,
            O.C_Zip,            
            O.C_City,
            O.C_Address2,
            O.C_Phone1,
            O.TrackingNo,
            O.ShipperKey,
            O.DeliveryPlace,            
            CASE WHEN LTRIM(ISNULL(O.DeliveryNote,'')) = '10' THEN '10' ELSE '' END,
            O.Storerkey                                   
   ORDER BY O.Storerkey, LPD.Loadkey, O.Orderkey,
            OD.Sku            
                                               
END -- procedure

GO