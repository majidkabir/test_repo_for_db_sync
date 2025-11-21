SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: isp_GetDespatchManifestUS                             */
/* Creation Date: 10-Oct-2007                                              */
/* Copyright: IDS                                                          */
/* Written by: YokeBeen                                                    */
/*                                                                         */
/* Purpose:  SOS#88393 - Load Manifest Detail Report for IDSUS.            */
/*                                                                         */
/* Called By:  PB - RCM                                                    */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Purposes                                         */
/* 14-Oct-2007  Vicky     Take out and add in fields (Vicky01)             */
/* 17-Oct-2007  Vicky     Take the Consignee Address from Orders (Vicky02) */
/* 25-Mac-2008  HFLiew    SOS#100122 Change the TotalCartons, SumTotal     */
/*                        and GrandTotal to 0 If PackType1 to PackType10   */
/*                        is equal to GOH                                  */
/* 04-Apr-2010 NJOW01    Change to cater for multi pickslip per order     */
/* 14-Jun-2012  NJOW02    246112-Weight and Carton for Master Pack and POCC*/
/* 25-Jun-2012  NJOW03    Change consoorderkey to externconsoorderkey      */
/* 06-Nov-2012  KHLim     DM integrity - Update EditDate (KH01)            */
/* 09-Jan-2013  YTWan     SOS# - Get C/O from Facility.Userdefine10 (Wan01)*/
/***************************************************************************/

CREATE PROC [dbo].[isp_GetDespatchManifestUS] (
         @c_mbolkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PrintedFlag NVARCHAR(10),@c_PackType1 NVARCHAR(10),@i_TotalCartonsGOH int,
           @c_Consigneekey NVARCHAR(15)  

    CREATE TABLE #RESULT
         ( PrintedFlag NVARCHAR(10) NULL,
              MBOLKey NVARCHAR(10) NULL, 
           DepartureDate datetime NULL, 
           TotalCartons float NULL, 
           Weight float NULL, 
           StorerKey NVARCHAR(15) NULL,
              ConsigneeKey NVARCHAR(15) NULL, 
              ExternOrderKey NVARCHAR(20) NULL,
              BuyerPO NVARCHAR(20) NULL,
           Userdefine03 NVARCHAR(20) NULL, 
              MarkforKey NVARCHAR(15) NULL,
              C_Company NVARCHAR(45) NULL,
           C_Address1 NVARCHAR(45) NULL, 
           C_Address2 NVARCHAR(45) NULL, 
           C_Address3 NVARCHAR(45) NULL, 
           C_Address4 NVARCHAR(45) NULL, 
           C_City NVARCHAR(45) NULL, 
           C_State NVARCHAR(2) NULL, 
           C_Zip NVARCHAR(18) NULL, 
              Company NVARCHAR(45) NULL,
           Facility_Descr NVARCHAR(50) NULL, -- Vicky01
           Facility_Usd01 NVARCHAR(30) NULL, -- Vicky01
           Facility_Usd03 NVARCHAR(30) NULL, -- Vicky01
           Facility_Usd04 NVARCHAR(30) NULL, -- Vicky01
           Facility_USD10 NVARCHAR(30) NULL, --(Wan01)
              TotalQty int NULL, 
           UserID NVARCHAR(18) NULL)

    CREATE TABLE #CTNINFO
          (TTLCTN           INT          NULL DEFAULT 0,  
          TTLWeight        REAL         NULL DEFAULT 0,  
          ExternConsoOrderkey    NVARCHAR(30)  NULL DEFAULT '',
          Consigneekey     NVARCHAR(15)  NULL DEFAULT '')

    IF EXISTS(SELECT 1 FROM MBOL WITH (NOLOCK) WHERE MBOLKey = @c_mbolkey AND COD_Status = 'P')
    BEGIN
       SELECT @c_PrintedFlag = 'REPRINT'
    END
    ELSE
    BEGIN
       SELECT @c_PrintedFlag = '' 
   
      UPDATE MBOL WITH (ROWLOCK)
      SET COD_Status = 'P',
          EditDate   = GETDATE(),  --KH01
          TrafficCop = NULL 
      WHERE MBOLKey = @c_mbolkey 
    END
   
   IF EXISTS(SELECT 1 FROM MBOLDETAIL MD (NOLOCK) 
             JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
             JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey 
             WHERE MD.MBOLKey = @c_mbolkey 
             AND ISNULL(OD.ConsoOrderKey,'') <> '')
   BEGIN    
       DECLARE cur_CTNINFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT Consigneekey
            FROM ORDERS (NOLOCK)
            WHERE Mbolkey = @c_mbolkey
      OPEN cur_CTNINFO  
      FETCH NEXT FROM cur_CTNINFO INTO @c_Consigneekey
      WHILE @@FETCH_STATUS = 0
      BEGIN
          INSERT INTO #CTNINFO (ExternConsoOrderkey, TTLCTN, TTLWeight, Consigneekey)
          SELECT ExternConsoOrderkey, SUM(TTLCTN), SUM(TTLWeight), @c_consigneekey  
         FROM [dbo].[fnc_GetVicsBOL_CartonInfo](@c_mbolkey, @c_consigneekey)
         GROUP BY ExternConsoOrderkey
          
         FETCH NEXT FROM cur_CTNINFO INTO @c_Consigneekey
      END
      CLOSE cur_CTNINFO  
      DEALLOCATE cur_CTNINFO           
     
      INSERT INTO #RESULT (
             PrintedFlag ,
              MBOLKey , 
             DepartureDate , 
             TotalCartons , 
             Weight , 
             StorerKey , 
              ConsigneeKey , 
              ExternOrderKey ,
              BuyerPO ,
             Userdefine03 , 
              MarkforKey ,
             C_Company, 
             C_Address1 , 
             C_Address2 , 
             C_Address3 , 
             C_Address4 , 
             C_City , 
             C_State , 
             C_Zip , 
              Company ,
             Facility_Descr, -- Vicky01
             Facility_Usd01, -- Vicky01
             Facility_Usd03, -- Vicky01
             Facility_Usd04, -- Vicky01
             Facility_USD10, --(Wan01)
              TotalQty , 
             UserID)      
      SELECT @c_PrintedFlag, 
                MBOL.MBOLKey , 
             CONVERT(CHAR(10), MBOL.Departuredate,101) , -- Vicky01
             CASE WHEN ISNULL(dbo.fnc_RTrim(MBOL.PackType1), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType2), '') = 'GOH' --SOS#100122
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType3), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType4), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType5), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType6), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType7), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType8), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType9), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType10), '') = 'GOH' 
             THEN 0 ELSE 
                  PACKCTN.TTLCTN  
             END, 
             PACKCTN.TTLWeight , 
             ORDERS.StorerKey , 
              ORDERS.ConsigneeKey , 
              ORDERDETAIL.ExternConsoOrderKey ,
              MAX(ORDERS.BuyerPO),
             MAX(ORDERS.Userdefine03), 
              ORDERS.MarkforKey ,
             MAX(ORDERS.C_Company),
             MAX(ORDERS.C_Address1) , 
             MAX(ORDERS.C_Address2) , 
             MAX(ORDERS.C_Address3) , 
             MAX(ORDERS.C_Address4) , 
             MAX(ORDERS.C_City) , 
             MAX(ORDERS.C_State) , 
             MAX(ORDERS.C_Zip) , 
              STORER.Company ,
             Facility.Descr, -- Vicky01
             Facility.Userdefine01, -- Vicky01
             Facility.Userdefine03, -- Vicky01
             Facility.Userdefine04, -- Vicky01
             Facility.Userdefine10, --(Wan01)
              SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) , 
             sUser_sName()
      FROM MBOL WITH (NOLOCK) 
      INNER JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.MBOLKey = MBOLDETAIL.MBOLKey )
      INNER JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey )
      INNER JOIN ORDERDETAIL WITH (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )
      INNER JOIN STORER WITH (NOLOCK) ON ( ORDERS.StorerKey = STORER.StorerKey ) 
      INNER JOIN Facility WITH (NOLOCK) ON (MBOL.Facility = Facility.Facility)
      LEFT JOIN (SELECT ExternConsoOrderkey, TTLCTN, TTLWeight, Consigneekey FROM #CTNINFO) 
                PACKCTN ON ORDERDETAIL.ExternConsoOrderkey = PACKCTN.ExternConsoOrderkey AND ORDERS.Consigneekey = PACKCTN.Consigneekey
      WHERE MBOL.MBOLKey = @c_mbolkey
      AND ORDERS.Status >= '5'
      GROUP BY MBOL.MBOLKey , 
             CONVERT(CHAR(10), MBOL.Departuredate,101), -- Vicky01
             CASE WHEN ISNULL(dbo.fnc_RTrim(MBOL.PackType1), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType2), '') = 'GOH' --SOS#100122
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType3), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType4), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType5), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType6), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType7), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType8), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType9), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType10), '') = 'GOH' 
             THEN 0 ELSE 
                    PACKCTN.TTLCTN
             END, 
             PACKCTN.TTLWeight , 
             ORDERS.StorerKey , 
              ORDERS.ConsigneeKey , 
              ORDERDETAIL.ExternConsoOrderKey ,
              --ORDERS.BuyerPO ,
             --ORDERS.Userdefine03 , 
              ORDERS.MarkforKey ,
             --ORDERS.C_Company,
             --ORDERS.C_Address1 , 
             --ORDERS.C_Address2 , 
             --ORDERS.C_Address3 , 
             --ORDERS.C_Address4 , 
             --ORDERS.C_City , 
             --ORDERS.C_State , 
             --ORDERS.C_Zip , 
             Facility.Descr, -- Vicky01
             Facility.Userdefine01, -- Vicky01
             Facility.Userdefine03, -- Vicky01
             Facility.Userdefine04, -- Vicky01
             Facility.Userdefine10, --(Wan01)
                STORER.Company
   END
   ELSE
   BEGIN
      INSERT INTO #RESULT (
             PrintedFlag ,
              MBOLKey , 
             DepartureDate , 
             TotalCartons , 
             Weight , 
             StorerKey , 
              ConsigneeKey , 
              ExternOrderKey ,
              BuyerPO ,
             Userdefine03 , 
              MarkforKey ,
             C_Company, 
             C_Address1 , 
             C_Address2 , 
             C_Address3 , 
             C_Address4 , 
             C_City , 
             C_State , 
             C_Zip , 
              Company ,
             Facility_Descr, -- Vicky01
             Facility_Usd01, -- Vicky01
             Facility_Usd03, -- Vicky01
             Facility_Usd04, -- Vicky01
             Facility_USD10, --(Wan01)
              TotalQty , 
             UserID)      
      SELECT @c_PrintedFlag, 
                MBOL.MBOLKey , 
             CONVERT(CHAR(10), MBOL.Departuredate,101) , -- Vicky01
             CASE WHEN ISNULL(dbo.fnc_RTrim(MBOL.PackType1), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType2), '') = 'GOH' --SOS#100122
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType3), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType4), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType5), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType6), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType7), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType8), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType9), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType10), '') = 'GOH' 
             THEN 0 ELSE 
                    CASE WHEN PACKCTN.totalctn IS NULL THEN MBOLDETAIL.TotalCartons ELSE PACKCTN.totalctn END 
             END, 
             MBOLDETAIL.Weight , 
             ORDERS.StorerKey , 
              ORDERS.ConsigneeKey , 
              ORDERS.ExternOrderKey ,
              ORDERS.BuyerPO ,
             ORDERS.Userdefine03 , 
              ORDERS.MarkforKey ,
             ORDERS.C_Company,
             ORDERS.C_Address1 , 
             ORDERS.C_Address2 , 
             ORDERS.C_Address3 , 
             ORDERS.C_Address4 , 
             ORDERS.C_City , 
             ORDERS.C_State , 
             ORDERS.C_Zip , 
              STORER.Company ,
             Facility.Descr, -- Vicky01
             Facility.Userdefine01, -- Vicky01
             Facility.Userdefine03, -- Vicky01
             Facility.Userdefine04, -- Vicky01
             Facility.Userdefine10, --(Wan01)
              SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) , 
             sUser_sName()
      FROM MBOL WITH (NOLOCK) 
      INNER JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.MBOLKey = MBOLDETAIL.MBOLKey )
      INNER JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey )
      INNER JOIN ORDERDETAIL WITH (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )
      INNER JOIN STORER WITH (NOLOCK) ON ( ORDERS.StorerKey = STORER.StorerKey ) 
      INNER JOIN Facility WITH (NOLOCK) ON (MBOL.Facility = Facility.Facility)
      LEFT JOIN (SELECT  Packheader.Orderkey, COUNT(DISTINCT PackDetail.LabelNo) totalctn
                  FROM Mboldetail MD (NOLOCK)   
                 JOIN PackHeader (NOLOCK) ON (MD.Orderkey = Packheader.Orderkey)
                 JOIN   PackDetail (NOLOCK) ON (PackHeader.Pickslipno = PackDetail.Pickslipno)
                  WHERE MD.Mbolkey = @c_mbolkey
                  AND   PackHeader.Status = '9' 
                 GROUP BY Packheader.Orderkey) PACKCTN ON Orders.Orderkey = PACKCTN.Orderkey
      WHERE MBOL.MBOLKey = @c_mbolkey
      AND ORDERS.Status >= '5'
      GROUP BY MBOL.MBOLKey , 
             CONVERT(CHAR(10), MBOL.Departuredate,101), -- Vicky01
             CASE WHEN ISNULL(dbo.fnc_RTrim(MBOL.PackType1), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType2), '') = 'GOH' --SOS#100122
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType3), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType4), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType5), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType6), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType7), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType8), '') = 'GOH'
             OR ISNULL(dbo.fnc_RTrim(MBOL.PackType9), '') = 'GOH' OR ISNULL(dbo.fnc_RTrim(MBOL.PackType10), '') = 'GOH' 
             THEN 0 ELSE 
                    CASE WHEN PACKCTN.totalctn IS NULL THEN MBOLDETAIL.TotalCartons ELSE PACKCTN.totalctn END 
             END, 
             MBOLDETAIL.Weight , 
             ORDERS.StorerKey , 
              ORDERS.ConsigneeKey , 
              ORDERS.ExternOrderKey ,
              ORDERS.BuyerPO ,
             ORDERS.Userdefine03 , 
              ORDERS.MarkforKey ,
             ORDERS.C_Company,
             ORDERS.C_Address1 , 
             ORDERS.C_Address2 , 
             ORDERS.C_Address3 , 
             ORDERS.C_Address4 , 
             ORDERS.C_City , 
             ORDERS.C_State , 
             ORDERS.C_Zip , 
             Facility.Descr, -- Vicky01
             Facility.Userdefine01, -- Vicky01
             Facility.Userdefine03, -- Vicky01
             Facility.Userdefine04, -- Vicky01
             Facility.Userdefine10, --(Wan01)
                STORER.Company
    END
   
   SELECT * FROM #RESULT 
   ORDER BY MBOLKey, StorerKey, ConsigneeKey, ExternOrderKey, BuyerPO, MarkforKey  
   
   DROP TABLE #RESULT
END

GO