SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************************/
/* Store Procedure: nsp_GetECCODeliveryNote                                          */
/* Creation Date: 24th Nov 2005                                                      */
/* Copyright: IDS                                                                    */
/* Written by: James                                                                 */
/*                                                                                   */
/* Purpose: Generate ECCO MBOL Delivery Note FBR43211                                */
/*                                                                                   */
/* Called By:                                                                        */
/*                                                                                   */
/* PVCS Version: 1.4                                                                 */
/*                                                                                   */
/* Version: 5.4                                                                      */
/*                                                                                   */
/* Data Modifications:                                                               */
/*                                                                                   */
/* Updates:                                                                          */
/* Date         Author     Ver   Purposes                                            */
/* 2006-11-24   James      1.0   FBR43211 Created                                    */
/* 2006-05-19   dhung      1.1   SOS51268 Change company info from                   */
/*                               MBOL level to LOAD level                            */
/* 2007-08-14   ACM        1.2   SOS82873 Change C_company, C_Address accord to      */
/*                               storerconfig                                        */
/* 2007-11-21   YokeBeen   1.3   SOS#91472 - data type changed for Sku Size - Size3  */
/*                               from structure Float to NVARCHAR(5).                    */
/*                               - Also some other structure fine tune.              */
/*                               - Changed variable @c_Sku to @c_SkuDescr.           */
/*                               - Truncate leading zeroes for Sku Size.             */
/*                               (YokeBeen01)                                        */
/* 2009-07-09   Vanessa    1.4   SOS#140021 Change SKU Format from 42464001011-0043  */
/*                               to 4246400101----1---43                  (Vanessa01)*/
/* 2009-11-11   NJOW01     1.5   152951 - ECCO Delivery Order report Change Order    */
/*                                  type from XDOCK to EC-MAIN and EC-MAIN-NI        */
/* 2010-03-04   Leong      1.6   SOS# 164045 - Bug Fix                               */
/*************************************************************************************/

CREATE PROCEDURE [dbo].[nsp_GetECCODeliveryNote] (@c_MBOLKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0

   DECLARE @c_LoadKey   NVARCHAR(10),
      @n_CartonNo       NVARCHAR(20),
      @c_Company        NVARCHAR(45),
      @c_ConsigneeKey   NVARCHAR(15),  -- (YokeBeen01)
      @d_MBOLEditDate   datetime,
      @d_MBOLETADate    datetime,
      @c_address1       NVARCHAR(45),
      @c_Address2       NVARCHAR(45),
      @c_address3       NVARCHAR(45),
      @c_Contact1       NVARCHAR(30),
      @c_Phone1         NVARCHAR(18),
      @c_OrderKey       NVARCHAR(10),
--       @c_ExternOrderKey NVARCHAR(10),
      @c_SkuDescr       NVARCHAR(20),  -- (YokeBeen01)
      @c_MaterialNumber NVARCHAR(18),
      @c_UCCNo          NVARCHAR(20),
      @c_Ordertype      NVARCHAR(10),
      @c_StorerKey      NVARCHAR(15),  -- (YokeBeen01)
      @c_TempMaterialNumber   NVARCHAR(18),
      @c_TempSKUSize    NVARCHAR(5), -- (YokeBeen01)
--       @f_SkuSize        float,
      @n_Qty            int,  -- (YokeBeen01)
      @c_SKUSize        NVARCHAR(5),  -- (YokeBeen01)
      @c_SkuSize1       NVARCHAR(5),  -- (YokeBeen01)
      @c_SkuSize2       NVARCHAR(5),  -- (YokeBeen01)
      @c_SkuSize3       NVARCHAR(5),  -- (YokeBeen01)
      @c_SkuSize4       NVARCHAR(5),
      @c_SkuSize5       NVARCHAR(5),
      @c_SkuSize6       NVARCHAR(5),
      @c_SkuSize7       NVARCHAR(5),
      @c_SkuSize8       NVARCHAR(5),
      @c_SkuSize9       NVARCHAR(5),
      @c_SkuSize10      NVARCHAR(5),
      @c_SkuSize11      NVARCHAR(5),
      @c_SkuSize12      NVARCHAR(5),
      @c_SkuSize13      NVARCHAR(5),
      @c_SkuSize14      NVARCHAR(5),
      @c_SkuSize15      NVARCHAR(5),
      @c_SkuSize16      NVARCHAR(5),
      @c_SkuSize17      NVARCHAR(5),
      @c_SkuSize18      NVARCHAR(5),
      @c_SkuSize19      NVARCHAR(5),
      @c_SkuSize20      NVARCHAR(5),
      @c_SkuSize21      NVARCHAR(5),
      @c_SkuSize22      NVARCHAR(5),
      @c_SkuSize23      NVARCHAR(5),
      @c_SkuSize24      NVARCHAR(5),
      @c_SkuSize25      NVARCHAR(5),
      @c_SkuSize26      NVARCHAR(5),
      @c_SkuSize27      NVARCHAR(5),
      @c_SkuSize28      NVARCHAR(5),
      @c_SkuSize29      NVARCHAR(5),
      @c_SkuSize30      NVARCHAR(5),
      @c_SkuSize31      NVARCHAR(5),
      @c_SkuSize32      NVARCHAR(5),
      @n_Qty1           int,
      @n_Qty2           int,
      @n_Qty3           int,
      @n_Qty4           int,
      @n_Qty5           int,
      @n_Qty6           int,
      @n_Qty7           int,
      @n_Qty8           int,
      @n_Qty9           int,
      @n_Qty10          int,
      @n_Qty11          int,
      @n_Qty12          int,
      @n_Qty13          int,
      @n_Qty14          int,
      @n_Qty15          int,
      @n_Qty16          int,
      @n_Qty17          int,
      @n_Qty18          int,
      @n_Qty19          int,
      @n_Qty20          int,
      @n_Qty21          int,
      @n_Qty22          int,
      @n_Qty23          int,
      @n_Qty24          int,
      @n_Qty25          int,
      @n_Qty26          int,
      @n_Qty27          int,
      @n_Qty28          int,
      @n_Qty29          int,
      @n_Qty30          int,
      @n_Qty31          int,
      @n_Qty32          int,
      @n_cnt            int,
      @b_success        int,
      @n_err            int,
      @c_errmsg         NVARCHAR(255)

   IF OBJECT_ID('tempdb..#TempMBOLDO') IS NOT NULL
      DROP TABLE #TempMBOLDO

   CREATE TABLE #TempMBOLDO (
   mbolkey        NVARCHAR(10) NULL,
   loadkey        NVARCHAR(10) NULL,
   c_company      NVARCHAR(45) NULL,
   editdate       datetime NULL,
   mboleta        datetime NULL,
   c_address2     NVARCHAR(45) NULL,
   c_address3     NVARCHAR(45) NULL,
   c_contact1     NVARCHAR(30) NULL,
   c_phone1       NVARCHAR(18) NULL,
   cartonno       NVARCHAR(20) NULL,
   materialnumber NVARCHAR(18) NULL,
   uccno          NVARCHAR(20) NULL,
   ordertype      NVARCHAR(10) NULL,
   skudescr       NVARCHAR(60) NULL,
   SkuSize1       NVARCHAR(5) NULL,
   SkuSize2       NVARCHAR(5) NULL,
   SkuSize3       NVARCHAR(5) NULL,
   SkuSize4       NVARCHAR(5) NULL,
   SkuSize5       NVARCHAR(5) NULL,
   SkuSize6       NVARCHAR(5) NULL,
   SkuSize7       NVARCHAR(5) NULL,
   SkuSize8       NVARCHAR(5) NULL,
   SkuSize9       NVARCHAR(5) NULL,
   SkuSize10      NVARCHAR(5) NULL,
   SkuSize11      NVARCHAR(5) NULL,
   SkuSize12      NVARCHAR(5) NULL,
   SkuSize13      NVARCHAR(5) NULL,
   SkuSize14      NVARCHAR(5) NULL,
   SkuSize15      NVARCHAR(5) NULL,
   SkuSize16      NVARCHAR(5) NULL,
   SkuSize17      NVARCHAR(5) NULL,
   SkuSize18      NVARCHAR(5) NULL,
   SkuSize19      NVARCHAR(5) NULL,
   SkuSize20      NVARCHAR(5) NULL,
   Qty1           int NULL,
   Qty2           int NULL,
   Qty3           int NULL,
   Qty4           int NULL,
   Qty5           int NULL,
   Qty6           int NULL,
   Qty7           int NULL,
   Qty8           int NULL,
   Qty9           int NULL,
   Qty10          int NULL,
   Qty11          int NULL,
   Qty12          int NULL,
   Qty13          int NULL,
   Qty14          int NULL,
   Qty15          int NULL,
   Qty16          int NULL,
   Qty17          int NULL,
   Qty18          int NULL,
   Qty19          int NULL,
   Qty20          int NULL,
   c_consigneekey NVARCHAR(15) NULL,  -- (YokeBeen01)
   c_address1     NVARCHAR(45) NULL,
   )

   SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''   --initialise counter
   SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''
   SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''
   SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''
   SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''

   SELECT @n_Qty1=0, @n_Qty2=0, @n_Qty3=0, @n_Qty4=0, @n_Qty5=0, @n_Qty6=0, @n_Qty7=0  ----initialise counter
   SELECT @n_Qty8=0, @n_Qty9=0, @n_Qty10=0, @n_Qty11=0, @n_Qty12=0, @n_Qty13=0, @n_Qty14=0
   SELECT @n_Qty15=0, @n_Qty16=0, @n_Qty17=0, @n_Qty18=0, @n_Qty19=0, @n_Qty20=0

   SELECT @c_StorerKey = StorerKey FROM Orders WITH (NOLOCK) WHERE MBOLKey = @c_MBOLKey
   SELECT @d_MBOLEditDate = editdate FROM MBOL WITH (NOLOCK) WHERE MBOLKey = @c_MBOLKey  --get mbol edit date

   SELECT @d_MBOLETADate = DateAdd(day, Ceiling(Cast(codelkup.Short AS REAL)), MBOL.EditDate)
     FROM MBOL WITH (NOLOCK)  --get mbol eta date
     JOIN Orders WITH (NOLOCK) ON MBOL.Mbolkey = Orders.Mbolkey
     JOIN Codelkup WITH (NOLOCK) ON Orders.C_City = Codelkup.Description
    WHERE MBOL.Mbolkey = @c_MBOLKey AND Codelkup.Listname = 'CityLdTime' AND Codelkup.Long = 'ECCO'

--   IF LTRIM(RTRIM(@d_MBOLETADate))='' OR @d_MBOLETADate IS NULL
   IF ISNULL(LTRIM(RTRIM(@d_MBOLETADate)),'') = ''
      SELECT @d_MBOLETADate = DateAdd(day, Ceiling(Cast(codelkup.Short AS REAL)), MBOL.EditDate)
        FROM MBOL WITH (NOLOCK)  --get mbol eta date from orders join storer if city = blank or city =null
        JOIN Orders WITH (NOLOCK) ON MBOL.MBOLKey = Orders.MBOLKey
        JOIN Storer WITH (NOLOCK) ON Orders.Consigneekey = Storer.StorerKey
        JOIN Codelkup WITH (NOLOCK) ON Storer.City = Codelkup.Description
       WHERE MBOL.MBOLKey = @c_MBOLKey AND Codelkup.Listname = 'CityLdTime' AND Codelkup.Long = 'ECCO'

   -- SOS51268 Change company info from MBOL level to LOAD level
   -- SELECT @C_Company = C_Company, @C_Address2 = C_Address2, @C_Address3 = C_Address3,
   --    @C_Contact1= C_Contact1, @C_Phone1 = C_Phone1 FROM Orders (NOLOCK) WHERE MBOLKey = @c_MBOLKey

   DECLARE cur_getloadkey CURSOR LOCAL FAST_FORWARD READ_ONLY
   FOR SELECT DISTINCT(loadkey) AS loadkey, type FROM Orders WITH (NOLOCK) WHERE mbolkey = @c_MBOLKey   --get loadkey within mbol

   OPEN cur_getloadkey
   FETCH NEXT FROM cur_getloadkey INTO @c_LoadKey, @c_Ordertype

   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- SOS51268 Change company info from MBOL level to LOAD level
      -- NOTE: In ECCO case, a LOAD might contains multiple Orders but will be from same customer
      SET ROWCOUNT 1

      -- SOS82873 Change company info from MBOL level to LOAD level
      -- NOTE: In ECCO case, 2 style, the English information saved in C_company, C_Address and Chinese Information saved in B_company,B_Address
    IF NOT EXISTS (SELECT 1
                  FROM ORDERS ORDERS WITH (NOLOCK),StorerConfig StorerConfig WITH (NOLOCK)
                  WHERE StorerConfig.StorerKey = ORDERS.StorerKey
                  AND StorerConfig.ConfigKey = 'UsedBillToAddressForPickSlip'
                  AND ORDERS.StorerKey = @c_StorerKey
        AND StorerConfig.Svalue = '1')
      BEGIN
         SELECT @C_Consigneekey = BillToKey, @C_Company = C_Company, @C_Address1 = C_Address1,
                @C_Address2 = C_Address2, @C_Address3 = C_Address3,
                @C_Contact1= C_Contact1, @C_Phone1 = C_Phone1
           FROM Orders WITH (NOLOCK)
          WHERE MBOLKey = @c_MBOLKey
            AND LoadKey = @c_LoadKey
      END
      ELSE
      BEGIN
         SELECT @C_Consigneekey = consigneekey, @C_Company = B_Company, @C_Address1 = B_Address1,
                @C_Address2 = B_Address2, @C_Address3 = B_Address3,
                @C_Contact1= C_Contact1, @C_Phone1 = C_Phone1
           FROM Orders WITH (NOLOCK)
          WHERE MBOLKey = @c_MBOLKey
            AND LoadKey = @c_LoadKey
      END

      SET ROWCOUNT 0

      IF OBJECT_ID('tempdb..#TempSKUSizeN') IS NOT NULL
         DROP TABLE #TempSKUSizeN

      IF OBJECT_ID('tempdb..#TempSKUSizeX') IS NOT NULL
         DROP TABLE #TempSKUSizeX

      --IF @c_Ordertype='XDOCK'
      IF @c_Ordertype IN ('EC-MAIN','EC-MAIN-NI')  --NJOW01
      BEGIN
         SELECT REPLACE(SUBSTRING(OD.SKU, 1, 14),'-','') AS MaterialNumber,  -- (Vanessa01)
                REPLACE(SUBSTRING(OD.SKU, 16, 5),'-','') AS SKUSize,         -- (Vanessa01)
                --OD.ShippedQty AS Qty,    -- SOS# 164045
                SUM(OD.ShippedQty) AS Qty, -- SOS# 164045
                LTRIM(RTRIM(OD.Userdefine01)) + LTRIM(RTRIM(OD.Userdefine02)) AS CartonNo
           INTO #TempSKUSizeX --get the unique material number, sizes & total qty within a carton into temp table
           FROM Orders O WITH (NOLOCK)
           JOIN Orderdetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
          WHERE O.LoadKey = @c_LoadKey
          GROUP BY REPLACE(SUBSTRING(OD.SKU, 1, 14),'-',''), REPLACE(SUBSTRING(OD.SKU, 16, 5),'-',''), -- (Vanessa01)
                   --OD.ShippedQty, -- SOS# 164045
                   OD.Userdefine01, OD.Userdefine02
          ORDER BY CartonNo
      END
      ELSE
      BEGIN
-- SOS# 164045 (start)
--         SELECT REPLACE(SUBSTRING(OD.SKU, 1, 14),'-','') AS MaterialNumber,               -- (Vanessa01)
--                REPLACE(SUBSTRING(OD.SKU, 16, 5),'-','') AS SKUSize,
--                PD.Qty,
--                PD.CartonNo  -- (Vanessa01)
--           INTO #TempSKUSizeN --get the unique material number, sizes & total qty within a carton into temp table
--           FROM Orders O WITH (NOLOCK)
--           JOIN Orderdetail OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
--           JOIN PackHeader PH WITH (NOLOCK) ON O.LoadKey = PH.LoadKey
--           JOIN Packdetail PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno AND OD.SKU = PD.SKU
--          WHERE PH.LoadKey = @c_LoadKey
--          GROUP BY REPLACE(SUBSTRING(OD.SKU, 1, 14),'-',''), REPLACE(SUBSTRING(OD.SKU, 16, 5),'-',''),  -- (Vanessa01)
--                   PD.Qty, PD.CartonNo
--          ORDER BY PD.CartonNo

         SELECT REPLACE(SUBSTRING(OD.SKU, 1, 14),'-','') AS MaterialNumber, -- (Vanessa01)
                REPLACE(SUBSTRING(OD.SKU, 16, 5),'-','') AS SKUSize,        -- (Vanessa01)
                SUM(PD.Qty) AS Qty,
                PD.CartonNo  -- (Vanessa01)
           INTO #TempSKUSizeN --get the unique material number, sizes & total qty within a carton into temp table
           FROM Orders O WITH (NOLOCK)
           JOIN (SELECT DISTINCT OrderKey, Sku
                 FROM OrderDetail WITH (NOLOCK) WHERE LoadKey = @c_LoadKey) AS OD
             ON O.OrderKey = OD.OrderKey
           JOIN PackHeader PH WITH (NOLOCK) ON O.LoadKey = PH.LoadKey
           JOIN Packdetail PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno AND OD.SKU = PD.SKU
          WHERE PH.LoadKey = @c_LoadKey
          GROUP BY REPLACE(SUBSTRING(OD.SKU, 1, 14),'-','') -- (Vanessa01)
                 , REPLACE(SUBSTRING(OD.SKU, 16, 5),'-','') -- (Vanessa01)
                 , PD.CartonNo
          ORDER BY PD.CartonNo
-- SOS# 164045 (end)
      END

      --IF @c_Ordertype='XDOCK'
      IF @c_Ordertype IN ('EC-MAIN','EC-MAIN-NI')  --NJOW01
         DECLARE cur_getmaterialnumber CURSOR LOCAL FAST_FORWARD READ_ONLY
            FOR SELECT DISTINCT(CartonNo) AS CartonNo FROM #TempSKUSizeX ORDER BY CartonNo   --select material number & assign size & qty to respective variable
      ELSE
         DECLARE cur_getmaterialnumber CURSOR LOCAL FAST_FORWARD READ_ONLY
            FOR SELECT DISTINCT(CartonNo) AS CartonNo FROM #TempSKUSizeN ORDER BY CartonNo   --select material number & assign size & qty to respective variable

      OPEN cur_getmaterialnumber
      FETCH NEXT FROM cur_getmaterialnumber INTO @n_CartonNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @n_cnt = 1

         SELECT @c_MaterialNumber = ''
         --IF @c_Ordertype='XDOCK'
         IF @c_Ordertype IN ('EC-MAIN','EC-MAIN-NI')  --NJOW01
            DECLARE cur_assignskusizenqty CURSOR LOCAL FAST_FORWARD READ_ONLY
               FOR SELECT MaterialNumber, SKUSize, Qty FROM #TempSKUSizeX
               WHERE CartonNo = @n_CartonNo ORDER BY MaterialNumber, SKUSize
         ELSE
            DECLARE cur_assignskusizenqty CURSOR LOCAL FAST_FORWARD READ_ONLY
               FOR SELECT MaterialNumber, SKUSize, Qty FROM #TempSKUSizeN
               WHERE CartonNo = @n_CartonNo ORDER BY MaterialNumber, SKUSize

            OPEN cur_assignskusizenqty

            FETCH NEXT FROM cur_assignskusizenqty INTO @c_MaterialNumber, @c_SKUSize, @n_Qty

            WHILE @@FETCH_STATUS=0
            BEGIN
               -- (YokeBeen01) - Start
               WHILE SUBSTRING(@c_SKUSize, 1, 1) = '0'
               BEGIN
                  SELECT @c_SKUSize = substring(@c_SKUSize,2, len(@c_SKUSize)-1)
               END
               -- (YokeBeen01) - End

               IF  @n_cnt = 1  select @c_SkuSize1 = @c_SKUSize
               IF  @n_cnt = 2  select @c_SkuSize2 = @c_SKUSize
               IF  @n_cnt = 3  select @c_SkuSize3 = @c_SKUSize
               IF  @n_cnt = 4  select @c_SkuSize4 = @c_SKUSize
               IF  @n_cnt = 5  select @c_SkuSize5 = @c_SKUSize
               IF  @n_cnt = 6  select @c_SkuSize6 = @c_SKUSize
               IF  @n_cnt = 7  select @c_SkuSize7 = @c_SKUSize
               IF  @n_cnt = 8  select @c_SkuSize8 = @c_SKUSize
               IF  @n_cnt = 9  select @c_SkuSize9 = @c_SKUSize
               IF  @n_cnt = 10 select @c_SkuSize10 = @c_SKUSize
               IF  @n_cnt = 11 select @c_SkuSize11 = @c_SKUSize
               IF  @n_cnt = 12 select @c_SkuSize12 = @c_SKUSize
               IF  @n_cnt = 13 select @c_SkuSize13 = @c_SKUSize
               IF  @n_cnt = 14 select @c_SkuSize14 = @c_SKUSize
               IF  @n_cnt = 15 select @c_SkuSize15 = @c_SKUSize
               IF  @n_cnt = 16 select @c_SkuSize16 = @c_SKUSize
               IF  @n_cnt = 17 select @c_SkuSize17 = @c_SKUSize
               IF  @n_cnt = 18 select @c_SkuSize18 = @c_SKUSize
               IF  @n_cnt = 19 select @c_SkuSize19 = @c_SKUSize
               IF  @n_cnt = 20 select @c_SkuSize20 = @c_SKUSize

               IF  @n_cnt = 1  select @n_Qty1 = @n_Qty
               IF  @n_cnt = 2  select @n_Qty2 = @n_Qty
               IF  @n_cnt = 3  select @n_Qty3 = @n_Qty
               IF  @n_cnt = 4  select @n_Qty4 = @n_Qty
               IF  @n_cnt = 5  select @n_Qty5 = @n_Qty
               IF  @n_cnt = 6  select @n_Qty6 = @n_Qty
               IF  @n_cnt = 7  select @n_Qty7 = @n_Qty
               IF  @n_cnt = 8  select @n_Qty8 = @n_Qty
               IF  @n_cnt = 9  select @n_Qty9 = @n_Qty
               IF  @n_cnt = 10 select @n_Qty10 = @n_Qty
               IF  @n_cnt = 11 select @n_Qty11 = @n_Qty
               IF  @n_cnt = 12 select @n_Qty12 = @n_Qty
               IF  @n_cnt = 13 select @n_Qty13 = @n_Qty
               IF  @n_cnt = 14 select @n_Qty14 = @n_Qty
               IF  @n_cnt = 15 select @n_Qty15 = @n_Qty
               IF  @n_cnt = 16 select @n_Qty16 = @n_Qty
               IF  @n_cnt = 17 select @n_Qty17 = @n_Qty
               IF  @n_cnt = 18 select @n_Qty18 = @n_Qty
               IF  @n_cnt = 19 select @n_Qty19 = @n_Qty
               IF  @n_cnt = 20 select @n_Qty20 = @n_Qty

               IF @c_TempMaterialNumber <> @c_MaterialNumber
               BEGIN
--                   SELECT @c_SKU = Descr FROM SKU (NOLOCK) WHERE StorerKey = @c_StorerKey AND SUBSTRING(SKU.SKU, 1, LEN(SKU.SKU)- 6) = @c_MaterialNumber
                  SELECT @c_SkuDescr = Descr FROM SKU SKU WITH (NOLOCK)
                   INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU
                   WHERE OD.StorerKey = @c_StorerKey
                     AND REPLACE(SUBSTRING(OD.SKU, 1, 14),'-','') = @c_MaterialNumber  -- (Vanessa01)

                  INSERT INTO #TempMBOLDO
                    (mbolkey, loadkey, c_company, c_consigneekey, editdate, mboleta, c_address1, c_address2,
                     c_address3, c_contact1, c_phone1, cartonno,  --insert into temp table for reporting purpose
                     materialnumber, uccno, ordertype, skudescr, SKUSize1, SKUSize2, SKUSize3, SkuSize4,
                     SkuSize5, SkuSize6, SkuSize7, SkuSize8, SkuSize9, SkuSize10, SkuSize11, SkuSize12,
                     SkuSize13, SkuSize14, SkuSize15, SkuSize16, SkuSize17, SkuSize18, SkuSize19, SkuSize20,
                     Qty1, Qty2, Qty3, Qty4, Qty5, Qty6, Qty7, Qty8,
                     Qty9, Qty10, Qty11, Qty12, Qty13, Qty14, Qty15, Qty16,
                     Qty17, Qty18, Qty19, Qty20)
                  VALUES
                     (@c_MBOLKey, @c_LoadKey, @c_Company, @c_Consigneekey, @d_MBOLEditDate, @d_MBOLETADate, @c_Address1, @c_Address2,
                      @c_Address3, @c_Contact1, @c_Phone1, @n_CartonNo,
                      @c_MaterialNumber, @n_CartonNo, @c_Ordertype, @c_SkuDescr, @c_SKUSize1, @c_SKUSize2, @c_SKUSize3, @c_SKUSize4, -- (YokeBeen01)
                      @c_SKUSize5, @c_SKUSize6, @c_SKUSize7, @c_SKUSize8, @c_SKUSize9, @c_SKUSize10, @c_SKUSize11, @c_SKUSize12,
                      @c_SKUSize13, @c_SKUSize14, @c_SKUSize15, @c_SKUSize16, @c_SKUSize17, @c_SKUSize18, @c_SKUSize19, @c_SKUSize20,
                      @n_Qty1, @n_Qty2, @n_Qty3, @n_Qty4, @n_Qty5, @n_Qty6, @n_Qty7, @n_Qty8,
                      @n_Qty9, @n_Qty10, @n_Qty11, @n_Qty12, @n_Qty13, @n_Qty14, @n_Qty15, @n_Qty16,
                 @n_Qty17, @n_Qty18, @n_Qty19, @n_Qty20)
               END
               ELSE
               BEGIN
                  IF @n_cnt = 1  UPDATE #TempMBOLDO SET Qty1 = Qty1 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 2  UPDATE #TempMBOLDO SET SKUSize2 = @c_SKUSize2, Qty2 = Qty2 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 3  UPDATE #TempMBOLDO SET SKUSize3 = @c_SKUSize3, Qty3 = Qty3 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 4  UPDATE #TempMBOLDO SET SKUSize4 = @c_SKUSize4, Qty4 = Qty4 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 5  UPDATE #TempMBOLDO SET SKUSize5 = @c_SKUSize5, Qty5 = Qty5 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 6  UPDATE #TempMBOLDO SET SKUSize6 = @c_SKUSize6, Qty6 = Qty6 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 7  UPDATE #TempMBOLDO SET SKUSize7 = @c_SKUSize7, Qty7 = Qty7 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 8  UPDATE #TempMBOLDO SET SKUSize8 = @c_SKUSize8, Qty8 = Qty8 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 9  UPDATE #TempMBOLDO SET SKUSize9 = @c_SKUSize9, Qty9 = Qty9 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 10 UPDATE #TempMBOLDO SET SKUSize10 = @c_SKUSize10, Qty10 = Qty10 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 11 UPDATE #TempMBOLDO SET SKUSize11 = @c_SKUSize11, Qty11 = Qty11 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 12 UPDATE #TempMBOLDO SET SKUSize12 = @c_SKUSize12, Qty12 = Qty12 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 13 UPDATE #TempMBOLDO SET SKUSize13 = @c_SKUSize13, Qty13 = Qty13 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 14 UPDATE #TempMBOLDO SET SKUSize14 = @c_SKUSize14, Qty14 = Qty14 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 15 UPDATE #TempMBOLDO SET SKUSize15 = @c_SKUSize15, Qty15 = Qty15 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 16 UPDATE #TempMBOLDO SET SKUSize16 = @c_SKUSize16, Qty16 = Qty16 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 17 UPDATE #TempMBOLDO SET SKUSize17 = @c_SKUSize17, Qty17 = Qty17 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 18 UPDATE #TempMBOLDO SET SKUSize18 = @c_SKUSize18, Qty18 = Qty18 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 19 UPDATE #TempMBOLDO SET SKUSize19 = @c_SKUSize19, Qty19 = Qty19 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
                  IF @n_cnt = 20 UPDATE #TempMBOLDO SET SKUSize20 = @c_SKUSize20, Qty20 = Qty20 + @n_Qty WHERE loadkey = @c_LoadKey AND cartonno = @n_CartonNo AND materialnumber = @c_MaterialNumber
               END

               SELECT @c_TempMaterialNumber = @c_MaterialNumber
               SELECT @c_TempSKUSize = @c_SKUSize
               SELECT @c_SkuSize1='', @c_SkuSize2='', @c_SkuSize3='', @c_SkuSize4='',@c_SkuSize5='', @c_SkuSize6='',@c_SkuSize7=''  --reset counters
               SELECT @c_SkuSize8='',@c_SkuSize9='', @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12='', @c_SkuSize13='', @c_SkuSize14=''
               SELECT @c_SkuSize15='', @c_SkuSize16='',@c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''

               SELECT @n_Qty1 = 0, @n_Qty2 = 0, @n_Qty3 = 0, @n_Qty4 = 0, @n_Qty5 = 0, @n_Qty6 = 0, @n_Qty7 = 0
               SELECT @n_Qty8 = 0, @n_Qty9 = 0, @n_Qty10 = 0, @n_Qty11= 0, @n_Qty12 = 0, @n_Qty13 = 0, @n_Qty14 = 0
               SELECT @n_Qty15 = 0, @n_Qty16 = 0, @n_Qty17 = 0, @n_Qty18 = 0, @n_Qty19 = 0, @n_Qty20 = 0

               FETCH NEXT FROM cur_assignskusizenqty INTO @c_MaterialNumber, @c_SKUSize, @n_Qty

               IF @c_TempMaterialNumber <> @c_MaterialNumber
                  SELECT @n_cnt = 1
               ELSE
                  IF @c_TempMaterialNumber = @c_MaterialNumber AND @c_TempSKUSize <> @c_SKUSize
                     SELECT @n_cnt = @n_cnt + 1
            END   --cur_assignskusizenqty

            CLOSE cur_assignskusizenqty
            DEALLOCATE  cur_assignskusizenqty

            SELECT @c_TempMaterialNumber=''
         FETCH NEXT FROM cur_getmaterialnumber INTO @n_CartonNo
      END   --cur_getmaterialnumber
      CLOSE cur_getmaterialnumber
      DEALLOCATE cur_getmaterialnumber

      FETCH NEXT FROM cur_getloadkey INTO @c_LoadKey, @c_Ordertype
   END   --cur_getloadkey

   CLOSE cur_getloadkey
   DEALLOCATE cur_getloadkey

   SELECT * FROM #TEMPMBOLDO (NOLOCK)--GROUP BY MaterialNumber

   DROP TABLE #TempMBOLDO
END

GO