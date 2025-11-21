SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_Print_SSCC_CartonLabel_03_uf            	      */
/* Creation Date: 08-Feb-2007                                      			*/
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                   				    	*/
/*                                                                      */
/* Purpose:  Pacific Brands - Print SSCC Carton Label (SOS68117)		    */
/*           Note: related to isp_GenSSCCLabelNo                        */
/*                                                                      */
/* Input Parameters: @cStorerKey - StorerKey,                           */
/*                   @cPickSlipNo - Pickslipno,                         */
/*                   @cFromCartonNo - From CartonNo,                    */
/*                   @cToCartonNo - To CartonNo,                        */
/*                   @cFilePath - File path that store the barcodes     */
/*                                                                      */
/* Usage: Call by dw = r_dw_sscc_cartonlabel                            */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 29-Mar-2007  MaryVong      1) Add Userdefine05 and AdvertisementCode */
/*                            2) Ensure UserDefine03 & 04 with leading  */
/*                               zeros if length less than 4            */
/* 26-Feb-2008  HFLiew        SOS#98666 add new fields                  */
/* 06-Apr-2023  WLChooi   1.1   WMS-22159 Extend Userdefine01 to 50 (C01)*/
/* 06-Apr-2023  WLChooi   1.1   DevOps Combine Script                   */ 
/************************************************************************/

CREATE   PROC [dbo].[isp_Print_SSCC_CartonLabel_03_uf] ( 
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10), 
   @cFromCartonNo NVARCHAR( 10),
   @cToCartonNo   NVARCHAR( 10),
   @cFilePath     NVARCHAR( 100) )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   -- Declare temp table
   DECLARE @tTempResult TABLE (
         StorerKey               NVARCHAR( 15) NULL,
         OrderKey                NVARCHAR( 10) NULL,
         CPO                     NVARCHAR( 20) NULL,
         OrderType               NVARCHAR( 10) NULL,
         OrdUserDefine01         NVARCHAR( 50) NULL,   --C01
         OrdUserDefine02         NVARCHAR( 20) NULL, -- Added by HFLIEW on 26-02-2008 for SOS#98666
         OrdUserDefine03         NVARCHAR( 20) NULL,
         OrdUserDefine04         NVARCHAR( 20) NULL,
         OrdUserDefine05         NVARCHAR( 20) NULL,
         AdvertisementCode1      NVARCHAR( 10) NULL,
         AdvertisementCode2      NVARCHAR( 20) NULL,
         OrderDate               datetime  NULL, -- Added by HFLIEW on 26-02-2008 for SOS#98666
         DeliveryDate            datetime  NULL,
         Div_StorerKey           NVARCHAR( 15) NULL,
         Div_Company             NVARCHAR( 45) NULL,
         Div_Addr1               NVARCHAR( 45) NULL,
         Div_City                NVARCHAR( 45) NULL,
         Div_State               NVARCHAR( 2)  NULL,
         Div_Zip                 NVARCHAR( 18) NULL,
         BillTo_StorerKey        NVARCHAR( 15) NULL,
         BillTo_Company          NVARCHAR( 45) NULL,
         BillTo_Addr1            NVARCHAR( 45) NULL,
         BillTo_Addr2            NVARCHAR( 45) NULL,
         BillTo_Addr3            NVARCHAR( 45) NULL,
         BillTo_Zip              NVARCHAR( 18) NULL,
         ShipTo_StorerKey        NVARCHAR( 15) NULL,
         ShipTo_Comapnay         NVARCHAR( 45) NULL,
         ShipTo_Addr1            NVARCHAR( 45) NULL,
         ShipTo_Addr2            NVARCHAR( 45) NULL,
         ShipTo_Addr3            NVARCHAR( 45) NULL,
         ShipTo_Zip              NVARCHAR( 18) NULL,
         CartonNo                int       NULL,
         SKU                     NVARCHAR( 20) NULL,
         SKUDesc                 NVARCHAR( 60) NULL,
         Color                   NVARCHAR( 3)  NULL,
         Size                    NVARCHAR( 3)  NULL,
         BillTo_Label            NVARCHAR( 20) NULL,  -- include brackets 
         BillTo_Barcode          NVARCHAR( 20) NULL,  -- exclude brackets
         SSCC_Label              NVARCHAR( 22) NULL,  -- include brackets
         SSCC_Barcode            NVARCHAR( 22) NULL,  -- exclude brackets
         BillTo_FilePath_Barcode NVARCHAR( 200) NULL, -- using file path + bmp to display barcode
         SSCC_FilePath_Barcode   NVARCHAR( 200) NULL  -- using file path + bmp to display barcode
         )

   DECLARE
      @b_debug                int

   DECLARE 
      @cOrderKey                NVARCHAR( 10),
      @cCPO                     NVARCHAR( 20),
      @cOrderType               NVARCHAR( 10),
      @cOrdUserDefine01         NVARCHAR( 50),   --C01
      @cOrdUserDefine02         NVARCHAR( 20), -- Added by HFLIEW on 26-02-2008 for SOS#98666
      @cOrdUserDefine03         NVARCHAR( 20),
      @cOrdUserDefine04         NVARCHAR( 20),
      @cOrdUserDefine05         NVARCHAR( 20),
      @cAdvertisementCode       NVARCHAR( 30),
      @cAdvertisementCode1      NVARCHAR( 10),
      @cAdvertisementCode2      NVARCHAR( 20),
      @dtOrderDate              datetime,  -- Added by HFLIEW on 26-02-2008 for SOS#98666
      @dtDeliveryDate           datetime,
      @cDiv_StorerKey           NVARCHAR( 15),
      @cDiv_Company             NVARCHAR( 45),
      @cDiv_Addr1               NVARCHAR( 45),
      @cDiv_City                NVARCHAR( 45),
      @cDiv_State               NVARCHAR( 2),
      @cDiv_Zip                 NVARCHAR( 18),
      @cBillTo_StorerKey        NVARCHAR( 15),
      @cBillTo_Company          NVARCHAR( 45),
      @cBillTo_Addr1            NVARCHAR( 45),
      @cBillTo_Addr2            NVARCHAR( 45),
      @cBillTo_Addr3            NVARCHAR( 45),
      @cBillTo_Zip              NVARCHAR( 18),
      @cShipTo_StorerKey        NVARCHAR( 15),
      @cShipTo_Comapnay         NVARCHAR( 45),
      @cShipTo_Addr1            NVARCHAR( 45),
      @cShipTo_Addr2            NVARCHAR( 45),
      @cShipTo_Addr3            NVARCHAR( 45),
      @cShipTo_Zip              NVARCHAR( 18),
      @nCntSKU                  int,
      @cSKU                     NVARCHAR( 20),
      @cSKUDesc                 NVARCHAR( 60),
      @cColor                   NVARCHAR( 3),
      @cSize                    NVARCHAR( 3),
      @cBillTo_Label            NVARCHAR( 20),
      @cBillTo_Barcode          NVARCHAR( 20),
      @cPartial_SSCC            NVARCHAR( 17),
      @cSSCC_Label              NVARCHAR( 22),
      @cSSCC_Barcode            NVARCHAR( 22),
      @nFromCartonNo            int,
      @nToCartonNo              int,
      @nCartonNo                int,
      @cLabelNo                 NVARCHAR( 20),
      @cBillTo_FilePath_Barcode NVARCHAR( 200),
      @cSSCC_FilePath_Barcode   NVARCHAR( 200),
      @cShort                   int -- Added By HFLiew on 12 Mac 2008 For SOS98666 for flexible digits

   SET @b_debug = 0

   SET @cSKU = ''
   SET @cSKUDesc = ''
   SET @cColor = ''
   SET @cSize = ''
   SET @cBillTo_Label = ''
   SET @cBillTo_Barcode = ''
   SET @cPartial_SSCC = ''
   SET @cSSCC_Label = ''
   SET @cSSCC_Barcode = ''
   SET @cBillTo_FilePath_Barcode = ''
   SET @cSSCC_FilePath_Barcode = ''

   SET @nFromCartonNo = CAST( @cFromCartonNo AS int)
   SET @nToCartonNo = CAST( @cToCartonNo AS int)

   IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @cPickSlipNo 
              AND StorerKey = @cStorerKey AND CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo)
   BEGIN
      -- Get general data
      SELECT 
         @cStorerKey         = OH.StorerKey,
         @cOrderKey          = OH.OrderKey,
         @cCPO               = CASE WHEN OH.ExternOrderKey IS NOT NULL AND OH.ExternOrderKey <> '' AND
                                         CHARINDEX('_', OH.ExternOrderKey) > 1
                               THEN SUBSTRING(OH.ExternOrderKey, 1, CHARINDEX('_', OH.ExternOrderKey) - 1) 
                  				 ELSE '' END,
         @cOrderType         = OH.Type,
         @cOrdUserDefine01   = OH.UserDefine01,
         @cOrdUserDefine02   = OH.UserDefine02,-- added by HFLIEW on 26-02-2008 for SOS#98666
         @cOrdUserDefine03   = OH.UserDefine03,
         @cOrdUserDefine04   = OH.UserDefine04,
         /*@cOrdUserDefine05   = OH.UserDefine05,
         @cAdvertisementCode = OH.Salesman,*/
         @cOrdUserDefine05   = '',
         @cAdvertisementCode = OH.UserDefine05,
         @dtOrderDate        = OH.OrderDate, -- added by HFLIEW on 26-02-2008 for SOS#98666
         @dtDeliveryDate     = OH.DeliveryDate,
         @cDiv_StorerKey     = DivCode.StorerKey,
         @cDiv_Company       = DivCode.Company,
         @cDiv_Addr1         = DivCode.Address1,
         @cDiv_City          = DivCode.City,
         @cDiv_State         = DivCode.State,
         @cDiv_Zip           = DivCode.Zip,
         @cBillTo_StorerKey  = BillTo.StorerKey,
         @cBillTo_Company    = BillTo.Company,
         @cBillTo_Addr1      = BillTo.Address1,
         @cBillTo_Addr2      = BillTo.Address2,
         @cBillTo_Addr3      = BillTo.Address3,
         @cBillTo_Zip        = BillTo.Zip,
         @cShipTo_StorerKey  = ShipTo.StorerKey,
         @cShipTo_Comapnay   = ShipTo.Company,
         @cShipTo_Addr1      = ShipTo.Address1,
         @cShipTo_Addr2      = ShipTo.Address2,
         @cShipTo_Addr3      = ShipTo.Address3,
         @cShipTo_Zip        = ShipTo.Zip
      FROM ORDERS OH (NOLOCK)
      INNER JOIN PACKHEADER PH (NOLOCK) ON (PH.LoadKey = OH.LoadKey AND
                                            PH.OrderKey = OH.OrderKey)
      INNER JOIN STORER DivCode (NOLOCK) ON (OH.BuyerPO = DivCode.StorerKey)
      INNER JOIN STORER BillTo (NOLOCK) ON (OH.BillToKey = BillTo.StorerKey)
      INNER JOIN STORER ShipTo (NOLOCK) ON (OH.ConsigneeKey = ShipTo.StorerKey)
      WHERE PH.PickSlipNo = @cPickSlipNo
      AND   PH.StorerKey  = @cStorerKey

-- Added by HFLiew on 12 Mac 2008 for SOS98666 to enable the digits dynamic value
        /* SELECT @cShort = CL.Short
      	FROM ORDERS OH (NOLOCK) INNER JOIN Codelkup CL (NOLOCK)
         ON OH.OrderGroup = CL.Code
      	WHERE OH.OrderKey = @cOrderKey AND CL.ListName = 'PBCNLabel'  */

		SELECT @cShort = CL.Short
      FROM ORDERS OH WITH (NOLOCK) INNER JOIN Codelkup CL WITH (NOLOCK)
         --ON OH.OrderGroup = CL.Code --SOS#117424
      ON LEFT(OH.Consigneekey, LEN(OH.CONSIGNEEKEY) - LEN(ISNULL(OH.USERDEFINE03,'')))   = CL.Code
      WHERE OH.OrderKey = @cOrderKey AND CL.ListName = 'VitalLabel'
      
      /* (KC02)  - START */
      IF ISNULL(@cShort, 0) = 0
      BEGIN
      	SELECT @cShort = CL.Short
      	FROM Codelkup CL WITH (NOLOCK)
         WHERE CL.ListName = 'VitalLabel'
         AND CL.Code = 'Default'
      END
      /* (KC02) - END */      	

      IF LEN(ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cOrdUserDefine03)),'')) <= @cShort
         SET @cOrdUserDefine03  = RIGHT(REPLICATE('0', @cShort) + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cOrdUserDefine03)),''), @cShort)
      ELSE
      	SET @cOrdUserDefine03  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cOrdUserDefine03)),'')	-- (KC02)

      IF LEN(ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cOrdUserDefine04)),'')) <= @cShort
         SET @cOrdUserDefine04  = RIGHT(REPLICATE('0', @cShort) + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cOrdUserDefine04)),''), @cShort)  
      ELSE
      	SET @cOrdUserDefine04  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cOrdUserDefine04)),'')  -- (KC02)

         -- If length of UserDefine03 & 04 <= 4, add leading zeros to make it equal to 4 digits
      /* IF LEN(LTRIM(RTRIM(@cOrdUserDefine03))) <= @cShort
          SET @cOrdUserDefine03  = RIGHT(REPLICATE('0', @cShort) + LTRIM(RTRIM(@cOrdUserDefine03)), @cShort)
 
       IF LEN(LTRIM(RTRIM(@cOrdUserDefine04))) <= @cShort
         SET @cOrdUserDefine04  = RIGHT(REPLICATE('0', @cShort) + LTRIM(RTRIM(@cOrdUserDefine04)), @cShort)  */
-- End of statement-------------------------------------------------------------------------------------- 
      -- Separate AdvertisementCode into 2 parts
      -- Eg. AD 1103 => part1 = AD, part2 = 1103
      IF LEN(ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cAdvertisementCode)),'')) > 0 and CharIndex(' ', @cAdvertisementCode) < LEN(ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cAdvertisementCode)),''))
      BEGIN
         SET @cAdvertisementCode1 = SUBSTRING(@cAdvertisementCode, 1, CharIndex(' ', @cAdvertisementCode) - 1)
         SET @cAdvertisementCode2 = SUBSTRING(@cAdvertisementCode, Charindex(' ', @cAdvertisementCode) + 1, LEN(@cAdvertisementCode) - CharIndex(' ', @cAdvertisementCode))
      END

      /*IF LEN(LTRIM(RTRIM(@cAdvertisementCode))) > 0 
      BEGIN
         SET @cAdvertisementCode1 = SUBSTRING(@cAdvertisementCode, 1, CharIndex(' ', @cAdvertisementCode) - 1)
         SET @cAdvertisementCode2 = SUBSTRING(@cAdvertisementCode, Charindex(' ', @cAdvertisementCode) + 1, LEN(@cAdvertisementCode) - CharIndex(' ', @cAdvertisementCode))
      END*/
      

      DECLARE @curLABEL CURSOR
      SET @curLABEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CartonNo, LabelNo, COUNT (DISTINCT SKU)
         FROM PACKDETAIL (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
         AND StorerKey = @cStorerKey 
         AND CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo
         GROUP BY CartonNo, LabelNo
         ORDER BY CartonNo

   	OPEN @curLABEL
   	FETCH NEXT FROM @curLABEL INTO @nCartonNo, @cLabelNo, @nCntSKU
   
   	WHILE @@FETCH_STATUS <> -1
   	BEGIN
         -- Get sku data if only one sku found. Otherwise leave it blank
         IF @nCntSKU = 1
         BEGIN
            SELECT 
               @cSKU     = SKU.SKU,
               @cSKUDesc = SKU.DESCR,
               @cColor   = SUBSTRING(SKU.BUSR1,  7, 3),
               @cSize    = SUBSTRING(SKU.BUSR1, 10, 3)
            FROM PACKDETAIL PD (NOLOCK)
            INNER JOIN SKU SKU (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND
                                            PD.SKU = SKU.SKU)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND   PD.StorerKey = @cStorerKey
            AND   PD.CartonNo = @nCartonNo
         END

         -- Form BillTo_Label
         -- Eg. 4210369204906055 => (421)036302(90)6055
         SELECT @cBillTo_Label = '(421)036' +
                  RTRIM(LTRIM(@cBillTo_Zip)) +
                  '(90)' +
                  CASE WHEN @cOrderType = 'DTDC' THEN RTRIM(LTRIM(@cOrdUserDefine03))
                       WHEN @cOrderType = 'DTStore' THEN RTRIM(LTRIM(@cOrdUserDefine04))
                       ELSE '' 
                  END
      
         -- Form BillTo_Barcode (removed brackets from BillTo_Label)
         SELECT @cBillTo_Barcode = master.dbo.fnc_GetCharASCII(202)+'421036' +
                  RTRIM(LTRIM(@cBillTo_Zip)) + master.dbo.fnc_GetCharASCII(202)+
                  '90' +
                  CASE WHEN @cOrderType = 'DTDC' THEN RTRIM(LTRIM(@cOrdUserDefine03))
                       WHEN @cOrderType = 'DTStore' THEN RTRIM(LTRIM(@cOrdUserDefine04))
                       ELSE '' 
                  END

         IF @b_debug = 1
            SELECT @cBillTo_Label '@cBillTo_Label', @cBillTo_Barcode '@cBillTo_Barcode'

         -- Form SSCC Label
         -- Eg. 00093139381000000010
         SET @cSSCC_Label = '(' + SUBSTRING(@cLabelNo, 1, 2) + ')' + SUBSTRING(@cLabelNo, 3, 18)
         SET @cSSCC_Barcode = master.dbo.fnc_GetCharASCII(202)+ @cLabelNo

         IF RIGHT(RTRIM(LTRIM(@cFilePath)), 1) <> '\'
            SET @cFilePath = RTRIM(LTRIM(@cFilePath)) + '\'

         -- Add file path
         SET @cBillTo_FilePath_Barcode = RTRIM(LTRIM(@cFilePath)) + RTRIM(LTRIM(@cBillTo_Barcode)) + '.bmp' 
         SET @cSSCC_FilePath_Barcode   = RTRIM(LTRIM(@cFilePath)) + RTRIM(LTRIM(@cSSCC_Barcode)) + '.bmp' 

         -- Insert @tTempResult
         INSERT INTO @tTempResult
            (CartonNo,
            SKU,
            SKUDesc,
            Color,
            Size,
            BillTo_Label,
            BillTo_Barcode,
            SSCC_Label,   
            SSCC_Barcode,
            BillTo_FilePath_Barcode,
            SSCC_FilePath_Barcode )
         VALUES
            (@nCartonNo,
            @cSKU,
            @cSKUDesc,
            @cColor,
            @cSize,
            @cBillTo_Label,
            @cBillTo_Barcode,
            @cSSCC_Label,   
            @cSSCC_Barcode,
            @cBillTo_FilePath_Barcode,
            @cSSCC_FilePath_Barcode)            
   
         FETCH NEXT FROM @curLABEL INTO @nCartonNo, @cLabelNo, @nCntSKU
   	END

      IF @b_debug = 1   
         SELECT * FROM @tTempResult
      
      -- Update @tTempResult
      UPDATE @tTempResult
      SET
         StorerKey          = @cStorerKey,
         OrderKey           = @cOrderKey,
         CPO                = @cCPO,
         OrderType          = @cOrderType,
         OrdUserDefine01    = @cOrdUserDefine01,
         OrdUserDefine02    = @cOrdUserDefine02,-- added by HFLIEW on 26-02-2008 for SOS#98666
         OrdUserDefine03    = @cOrdUserDefine03,
         OrdUserDefine04    = @cOrdUserDefine04,
         OrdUserDefine05    = @cOrdUserDefine05,
         AdvertisementCode1 = @cAdvertisementCode1,
         AdvertisementCode2 = @cAdvertisementCode2,
         OrderDate          = @dtOrderDate, -- added by HFLIEW on 26-02-2008 for SOS#98666
         DeliveryDate       = @dtDeliveryDate,
         Div_StorerKey      = @cDiv_StorerKey,
         Div_Company        = @cDiv_Company,
         Div_Addr1          = @cDiv_Addr1,
         Div_City           = @cDiv_City,
         Div_State          = @cDiv_State,
         Div_Zip            = @cDiv_Zip,
         BillTo_StorerKey   = @cBillTo_StorerKey,
         BillTo_Company     = @cBillTo_Company,
         BillTo_Addr1       = @cBillTo_Addr1,
         BillTo_Addr2       = @cBillTo_Addr2,
         BillTo_Addr3       = @cBillTo_Addr3,
         BillTo_Zip         = @cBillTo_Zip,
         ShipTo_StorerKey   = @cShipTo_StorerKey,
         ShipTo_Comapnay    = @cShipTo_Comapnay,
         ShipTo_Addr1       = @cShipTo_Addr1,
         ShipTo_Addr2       = @cShipTo_Addr2,
         ShipTo_Addr3       = @cShipTo_Addr3,
         ShipTo_Zip         = @cShipTo_Zip 

   END -- CartonNo exists
   
   SELECT 
      StorerKey,
      OrderKey,
      CPO,
      OrderType,
      OrdUserDefine01,
      OrdUserDefine02,--added by HFLIEW on 26-02-2008 for SOS#98666
      OrdUserDefine03,
      OrdUserDefine04,
      OrdUserDefine05,
      AdvertisementCode1,
      AdvertisementCode2,
      OrderDate, --added by HFLIEW on 26-02-2008 for SOS#98666
      DeliveryDate,
      Div_StorerKey,
      Div_Company,
      Div_Addr1,
      Div_City,
      Div_State,
      Div_Zip,
      BillTo_StorerKey,
      BillTo_Company,
      BillTo_Addr1,
      BillTo_Addr2,
      BillTo_Addr3,
      BillTo_Zip,
      ShipTo_StorerKey,
      ShipTo_Comapnay,
      ShipTo_Addr1,
      ShipTo_Addr2,
      ShipTo_Addr3,
      ShipTo_Zip,
      CartonNo,
      SKU,
      SKUDesc,
      Color,
      Size,
      BillTo_Label,    -- include brackets 
      BillTo_Barcode,  -- exclude brackets
      SSCC_Label,      -- include brackets
      SSCC_Barcode,    -- exclude brackets  
      BillTo_FilePath_Barcode, -- using file path + bmp to display barcode
      SSCC_FilePath_Barcode    -- using file path + bmp to display barcode
   FROM @tTempResult

END

GO