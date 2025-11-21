SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Print_CartonLabel_01                           */
/* Creation Date: 28-SEP-2017                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-2984  - [TW-ECO] RCMreport Carton Label                 */
/*                                                                      */
/* Called By: PB - Loadplan & Report Modules                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/

CREATE PROC [dbo].[isp_Print_CartonLabel_01] (
       @cLoadKey       NVARCHAR(10) = '', 
       @cPickSlipNo    NVARCHAR(10) = '', 
       @nNoOfCartons   int = 1
)
AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        

   DECLARE @n_continue    int,
           @c_errmsg      NVARCHAR(255),
           @b_success     int,
           @n_err         int, 
           @b_debug       int

      DECLARE @n_cnt INT
   
      DECLARE @c_storerkey NVARCHAR(20)

   CREATE Table #temp_Ctn01Result  (
         loadkey              NVARCHAR(10),
         storerkey            NVARCHAR(10),
         DeliveryDate         DATETIME,
         OHDoor               NVARCHAR(20),
         C_Company            NVARCHAR(45),
         C_Address1           NVARCHAR(45),
         C_Address2           NVARCHAR(45),
         ExternOrderKey       NVARCHAR(20),
         ODUDF                NVARCHAR(36),
       --  ODUDE02              NVARCHAR(18),
         FDescr               NVARCHAR(50),     
         FAddress1            NVARCHAR(45), 
         FPhone01             NVARCHAR(18),
         PDLoc                NVARCHAR(20),
        -- CtnNo                INT,
        -- TTLCTN               INT, 
         rowid                int IDENTITY(1,1)   )
         
         SET @c_storerkey = ''
         
         SELECT TOP 1 @c_storerkey = O.Storerkey
         FROM ORDERS O (NOLOCK)
         WHERE o.loadkey = @cLoadKey


  INSERT INTO #temp_Ctn01Result (loadkey, storerkey, DeliveryDate, OHDoor,
              C_Company, C_Address1, C_Address2, ExternOrderKey, ODUDF,
              FDescr, FAddress1, FPhone01,PDLoc)--, CtnNo, TTLCTN)
  SELECT  o.loadkey,o.storerkey,o.DeliveryDate,'#'+ isNull(o.route,''),
  ISNULL(o.C_Company,''),
  ISNULL(o.C_Address1,''),
  ISNULL(o.C_Address2,''),
  ISNULL(o.ExternOrderKey,''),
  RTRIM(LTRIM((ISNULL(od.UserDefine01,'')+ISNULL(od.UserDefine02,'')))),ISNULL(f.Descr,''),ISNULL(f.Address1,''),ISNULL(f.Phone1,''),
     --    ,cntno = ROW_NUMBER() OVER (PARTITION BY od.UserDefine01,od.UserDefine02 ORDER BY (od.UserDefine01+od.UserDefine02) ASC) 
     --    ,ttlctn = SUM(1) OVER (PARTITION BY od.UserDefine01,od.UserDefine02 ORDER BY (od.UserDefine01+od.UserDefine02) ASC)
  PD.Loc
  FROM ORDERS O (NOLOCK)
  JOIN ORDERDETAIL OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)
  JOIN LOADPLANDETAIL LD (NOLOCK) on (OD.Orderkey = LD.Orderkey AND OD.Loadkey = LD.Loadkey) 
  JOIN LOADPLAN L (NOLOCK) ON (L.Loadkey = OD.Loadkey) 
  JOIN FACILITY F (NOLOCK) ON F.facility = o.Facility
  JOIN PickDetail PD on (PD.OrderKey=OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
  WHERE o.StorerKey=@c_storerkey
  AND o.LoadKey=@cLoadKey
  GROUP BY o.loadkey,o.storerkey,o.DeliveryDate,'#'+ isNull(o.route,''),
  ISNULL(o.C_Company,''),
  ISNULL(o.C_Address1,''),
  ISNULL(o.C_Address2,''),
  ISNULL(o.ExternOrderKey,''),
  ISNULL(od.UserDefine01,''),ISNULL(od.UserDefine02,''),ISNULL(f.Descr,''),ISNULL(f.Address1,''),ISNULL(f.Phone1,''),
  PD.Loc
  ORDER BY o.loadkey desc
   
--Quit:


   SELECT DISTINCT loadkey, storerkey, DeliveryDate, OHDoor,
                   C_Company, C_Address1, C_Address2, ExternOrderKey, ODUDF,
                   FDescr, FAddress1, FPhone01--, CtnNo, TTLCTN
                   ,cntno = ROW_NUMBER() OVER (PARTITION BY ExternOrderKey ORDER BY loadkey,ExternOrderKey,PDLoc ASC) 
                   ,ttlctn = SUM(1) OVER (PARTITION BY ExternOrderKey ORDER BY  ExternOrderKey ASC),
                    PDLoc
    FROM #temp_Ctn01Result 
   ORDER BY loadkey,PDLoc,ExternOrderKey,cntno 
END


GO