SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: isp_IDXShopLabelCoverPage                                */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#273078 - Print Shop label cover page                         */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2013-03-28 1.0  James    Created                                          */
/* 2014-04-03 2.0  SPChin   SOS307411 - Sort By ID                           */
/* 2014-04-04 2.1  James    SOS307345 - Add custom sp to build label(james01)*/
/*                          Only look at SKU.Busr5                           */
/* 2014-10-28 1.1  James    SOS324404 Extend var length (james02)            */     
/*****************************************************************************/

CREATE PROC [dbo].[isp_IDXShopLabelCoverPage](
   @cLoadKey         NVARCHAR( 10),
   @cLabelType       NVARCHAR( 10),
   @cStorerKey       NVARCHAR( 15),
   @nFunc            INT
) AS

   DECLARE
      @cShopLabelType      NVARCHAR( 10),
      @nErrNo              INT,
      @cErrMsg             NVARCHAR( 20),
      @cLangCode           NVARCHAR( 3),
      @cSKUFilter          NVARCHAR( 10),
      @cSKUFilterT         NVARCHAR( 10),
      @cLOC                NVARCHAR( 10),
      @cSKU                NVARCHAR( 20),
      @cSection            NVARCHAR( 5),
      @nTTL_Shop           INT,
      @nTTL_Qty            INT

   DECLARE
      @cConsigneeKey       NVARCHAR( 15),
      @cSeparate           NVARCHAR( 5),
      @cBultoNo            NVARCHAR( 5),
      @cMaxBultoNo         NVARCHAR( 5),
      @cMinBultoNo         NVARCHAR( 5),
      @cUDF03              NVARCHAR( 30),
      @cUDF04              NVARCHAR( 30),
      @cCode               NVARCHAR( 30),
      @cTempBarcodeFrom    NVARCHAR( 20),
      @cDistCenter         NVARCHAR( 6),  -- (james02)
      @cShopNo             NVARCHAR( 6),  -- (james02)
      @cCheckDigit         NVARCHAR( 1),
      @nBultoNo            INT,
      @nStorePrintQty      INT,
      @nNewBultoNo         INT,
      @nTranCount          INT

   DECLARE
      @cCompany   NVARCHAR( 45),
      @cAddress1  NVARCHAR( 45),
      @cAddress2  NVARCHAR( 45),
      @cAddress3  NVARCHAR( 45),
      @cAddress4  NVARCHAR( 45),
      @cZip       NVARCHAR( 18),
      @cCity      NVARCHAR( 45),
      @cContact1  NVARCHAR( 30),
      @cContact2  NVARCHAR( 30)

   DECLARE @cBuildLabelNo  NVARCHAR( 20), 
           @cLabelNo_Out   NVARCHAR( 20), 
           @bSuccess       INT 

   SET @cSKUFilter = rdt.RDTGetConfig( @nFunc, 'PrintShopLabelSKUFilter', @cStorerKey)
   SET @cSKUFilterT = rdt.RDTGetConfig( @nFunc, 'PrintShopLabelSKUFilterT', @cStorerKey)

   CREATE TABLE #TEMP_SHOPLBL
   (  ID             INT IDENTITY(1,1) NOT NULL,
      TAG            NVARCHAR( 1)  NULL,
      LoadKey        NVARCHAR( 10) NULL,
      LOC            NVARCHAR( 10) NULL,
      SKU            NVARCHAR( 20) NULL,
      StorerKey      NVARCHAR( 15) NULL,
      TTL_Shop       INT           NULL,
      TTL_Qty        INT           NULL,
      Company        NVARCHAR( 45) NULL,
      Address1       NVARCHAR( 45) NULL,
      Address2       NVARCHAR( 45) NULL,
      Address3       NVARCHAR( 45) NULL,
      Address4       NVARCHAR( 45) NULL,
      Zip            NVARCHAR( 18) NULL,
      City           NVARCHAR( 45) NULL,
      ShopNo         NVARCHAR( 6),        -- (james02)
      Section        NVARCHAR( 5),
      Separate       NVARCHAR( 5),
      Bulto          NVARCHAR( 5),
      Contact1       NVARCHAR( 30) NULL,
      Contact2       NVARCHAR( 30) NULL,
      Barcode        NVARCHAR( 30) )

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN PRINT_SHOPLBL

   SELECT @cShopLabelType = Short
   FROM dbo.CodeLkUp WITH (NOLOCK)
   WHERE ListName = 'SHPLBLTYPC'
   AND   StorerKey = @cStorerKey
   AND   Code = @cLabelType

   SELECT @cDistCenter = ISNULL( UDF01, '')
   FROM dbo.CodeLkUp WITH (NOLOCK)
   WHERE ListName = 'SHPLBLTYPC'
   AND   Short = @cShopLabelType
   AND   StorerKey = @cStorerKey

   SET @cDistCenter = CASE WHEN LEN( RTRIM( @cDistCenter)) = 4 THEN  
                           RIGHT( '0000' + RTRIM(LTRIM(@cDistCenter)), 4)  
                      ELSE RIGHT( '000000' + RTRIM(LTRIM(@cDistCenter)), 6) END -- (james02)


   IF @cLabelType = 'GARMENTS'
   BEGIN
      DECLARE CUR_HEADER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PD.LOC,
             PD.SKU,
             O.SectionKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE OD.LoadKey = @cLoadKey
      AND   PD.Status = '0'
      AND   SKU.BUSR5 = CASE WHEN ISNULL(@cSKUFilter, '') NOT IN ('', '0') THEN @cSKUFilter ELSE SKU.BUSR5 END
      GROUP BY PD.LOC, PD.SKU, O.SectionKey
      ORDER BY PD.LOC, PD.SKU
   END
   ELSE IF @cLabelType = 'TEMPE'
   BEGIN
      DECLARE CUR_HEADER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PD.LOC,
             PD.SKU,
             O.SectionKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE OD.LoadKey = @cLoadKey
      AND   PD.Status = '0'
      AND   SKU.BUSR5 = CASE WHEN ISNULL(@cSKUFilterT, '') NOT IN ('', '0') THEN @cSKUFilterT ELSE SKU.BUSR5 END
      GROUP BY PD.LOC, PD.SKU, O.SectionKey
      ORDER BY PD.LOC, PD.SKU
   END
   ELSE
   BEGIN
      DECLARE CUR_HEADER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PD.LOC,
             PD.SKU,
             O.SectionKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE OD.LoadKey = @cLoadKey
      AND   PD.Status = '0'
      GROUP BY PD.LOC, PD.SKU, O.SectionKey
      ORDER BY PD.LOC, PD.SKU
   END

   OPEN CUR_HEADER
   FETCH NEXT FROM CUR_HEADER INTO @cLOC, @cSKU, @cSection
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @cLabelType = 'GARMENTS'
      BEGIN
         SELECT @nTTL_Shop = COUNT( DISTINCT O.ConsigneeKey), @nTTL_Qty = ISNULL( SUM( PD.QTY)/SKU.BUSR10, 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE OD.LoadKey = @cLoadKey
         AND   PD.Status = '0'
         AND   SKU.BUSR5 = CASE WHEN ISNULL(@cSKUFilter, '') NOT IN ('', '0') THEN @cSKUFilter ELSE SKU.BUSR5 END
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cSKU
         GROUP BY SKU.BUSR10
      END
      ELSE IF @cLabelType = 'TEMPE'
      BEGIN
         SELECT @nTTL_Shop = COUNT( DISTINCT O.ConsigneeKey), @nTTL_Qty = ISNULL( SUM( PD.QTY)/SKU.BUSR10, 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE OD.LoadKey = @cLoadKey
         AND   PD.Status = '0'
         AND   SKU.BUSR5 = CASE WHEN ISNULL(@cSKUFilterT, '') NOT IN ('', '0') THEN @cSKUFilterT ELSE SKU.BUSR5 END
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cSKU
         GROUP BY SKU.BUSR10
      END
      ELSE
      BEGIN
         SELECT @nTTL_Shop = COUNT( DISTINCT O.ConsigneeKey), @nTTL_Qty = ISNULL( SUM( PD.QTY)/SKU.BUSR10, 0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE OD.LoadKey = @cLoadKey
         AND   PD.Status = '0'
         AND   PD.LOC = @cLOC
         AND   PD.SKU = @cSKU
         GROUP BY SKU.BUSR10
      END

      SET @cSKU = RTRIM(@cSKU)

      INSERT INTO #TEMP_SHOPLBL
      (TAG, LoadKey, Loc, SKU, StorerKey, TTL_Shop, TTL_Qty,
       Company, Address1, Address2, Address3, Address4, Zip, City, ShopNo, Section, Separate, Bulto, Contact1, Contact2, Barcode)
      VALUES
      ('H', @cLoadKey, @cLOC, @cSKU, @cStorerKey, @nTTL_Shop, @nTTL_Qty,
       '', '', '', '', '', '', '', '', @cSection, '', '', '', '', '')

      DECLARE CUR_DETAIL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT O.ConsigneeKey,
             O.UserDefine02,
             ISNULL( SUM( PD.QTY)/SKU.BUSR10, 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      JOIN dbo.Storer ST WITH (NOLOCK) ON (O.ConsigneeKey = ST.StorerKey AND ST.Type = '2')
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE OD.LoadKey = @cLoadKey
      AND   PD.Status = '0'
      AND   PD.LOC = @cLOC
      AND   PD.SKU = @cSKU
      GROUP BY O.ConsigneeKey, O.UserDefine02, SKU.BUSR10, O.Userdefine05
      ORDER BY O.Userdefine05, O.ConsigneeKey
      OPEN CUR_DETAIL
      FETCH NEXT FROM CUR_DETAIL INTO @cConsigneeKey, @cSeparate, @nStorePrintQty
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         WHILE @nStorePrintQty > 0
         BEGIN
            SET @cShopNo = REPLACE( @cConsigneeKey, 'ITX', '')

            IF EXISTS (SELECT 1
                       FROM dbo.CODELKUP WITH (NOLOCK)
                       WHERE ListName = @cShopLabelType
                       AND   UDF01 = RTRIM(@cSection)
                       AND   StorerKey = RTRIM(@cStorerKey)
                       AND   Long = RTRIM(@cShopNo))
            BEGIN
               SELECT @cBultoNo = UDF05,
                      @cMinBultoNo = UDF03,
                      @cMaxBultoNo = UDF04
               FROM dbo.CODELKUP WITH (NOLOCK)
               WHERE ListName = @cShopLabelType
               AND   UDF01 = RTRIM(@cSection)
               AND   StorerKey = RTRIM(@cStorerKey)
               AND   Long = RTRIM(@cShopNo)

               -- 1st time setup or data error then reset
               IF ISNULL(@cBultoNo, '') = '' OR @cBultoNo = '0'
               BEGIN
                  SET @nBultoNo = CAST(ISNULL(@cMinBultoNo, '') AS INT) + 1
               END
               ELSE
               BEGIN
                  IF (CAST(@cBultoNo AS INT) + 1) > CAST(@cMaxBultoNo AS INT)
                     SET @nBultoNo = CAST(@cMinBultoNo AS INT) + 1
                  ELSE
                     SET @nBultoNo = CAST(@cBultoNo AS INT) + 1
               END
            END
            ELSE
            BEGIN
               IF ISNULL(@cSection, '') = ''
               BEGIN
                  -- If not exists then copy from same storer + udf01 + udf02
                  SELECT TOP 1 @nBultoNo = CAST(UDF03 AS INT) + 1
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE ListName = @cShopLabelType
                  AND   UDF01 = RTRIM(@cSection)
                  AND   StorerKey = RTRIM(@cStorerKey)
               END
               ELSE
               BEGIN
                  SELECT TOP 1
                     @cUDF03 = UDF03,
                     @cUDF04 = UDF04
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE ListName = @cShopLabelType
                  --AND   Short = 'SAMPLE'
                  AND   UDF01 = RTRIM(@cSection)
                  --AND   UDF02 = RTRIM(@cSeparate)
                  AND   StorerKey = RTRIM(@cStorerKey)
                  GROUP BY UDF03, UDF04, CODE
                  ORDER BY CODE DESC

                  -- Get Codelkup.CODE. Uniquekey is listname+code+storerkey
                  SELECT TOP 1
                     @cCode = LEFT(RTRIM(CODE), 6) + RIGHT('000' + CAST(MAX(CAST(RIGHT(RTRIM(CODE), 3) AS INT)) + 1 AS NVARCHAR(3)), 3)
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE ListName = @cShopLabelType
                  AND   StorerKey = RTRIM(@cStorerKey)
                  GROUP BY CODE
                  ORDER BY CODE DESC

                  SET @nBultoNo = CAST(@cUDF03 AS INT) + 1
                  SET @nNewBultoNo = CAST(@cUDF03 AS INT)

                  -- Insert new entry if record not exists (unique key listname + storerkey + udf01 + udf02 + long)
                  INSERT INTO dbo.CODELKUP (ListName, Code, Long, StorerKey,
                               UDF01, UDF02, UDF03, UDF04, UDF05)
                  VALUES (@cShopLabelType, @cCode, @cShopNo, @cStorerKey,
                          ISNULL(@cSection, ''), ISNULL(@cSeparate, ''), ISNULL(@cUDF03, ''), ISNULL(@cUDF04, ''), @nNewBultoNo)

                  IF @@ERROR <> 0
                  BEGIN
                     ROLLBACK TRAN PRINT_SHOPLBL
                     WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN

                     GOTO Quit
                  END
               END
            END

            SET @cBuildLabelNo = ''    
            SET @cBuildLabelNo = rdt.RDTGetConfig( @nFunc, 'BuildLabelNo', @cStorerkey)    

            IF ISNULL(@cBuildLabelNo,'') NOT IN ('', '0')    
            BEGIN    
               EXEC dbo.ispBuildShopLabel_Wrapper    
                   @c_SPName     = @cBuildLabelNo   
                  ,@c_LoadKey    = @cLoadKey
                  ,@c_LabelType  = @cLabelType 
                  ,@c_StorerKey  = @cStorerKey  
                  ,@c_DistCenter = @cDistCenter 
                  ,@c_ShopNo     = @cShopNo 
                  ,@c_Section    = @cSection 
                  ,@c_Separate   = @cSeparate 
                  ,@n_BultoNo    = @nBultoNo
                  ,@c_LabelNo    = @cLabelNo_Out   OUTPUT   -- Label out    
                  ,@b_Success    = @bSuccess       OUTPUT    
                  ,@n_ErrNo      = @nErrNo         OUTPUT    
                  ,@c_ErrMsg     = @cErrMsg        OUTPUT   
          
               IF @bSuccess <> '1'    
               BEGIN    
                  ROLLBACK TRAN PRINT_SHOPLBL  
                  WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  

                  GOTO Quit  
               END    
    
               SET @cTempBarcodeFrom = @cLabelNo_Out
            END

            EXEC [dbo].[isp_IDXShopAddress]
               @cConsigneeKey,
               @cCompany       OUTPUT,
               @cAddress1      OUTPUT,
               @cAddress2      OUTPUT,
               @cAddress3      OUTPUT,
               @cAddress4      OUTPUT,
               @cZip           OUTPUT,
               @cCity          OUTPUT,
               @cContact1      OUTPUT,
               @cContact2      OUTPUT

            INSERT INTO #TEMP_SHOPLBL
            (TAG, LoadKey, Loc, SKU, StorerKey, TTL_Shop, TTL_Qty,
            Company, Address1, Address2, Address3, Address4, Zip, City,
            ShopNo, Section, Separate, Bulto, Barcode, Contact1, Contact2)
            VALUES
            ('D', '', @cLOC, @cSKU, '', 0, 0, @CCompany, @cAddress1, @cAddress2, @cAddress3, @cAddress4, @cZip, @cCity,
            @cShopNo, CASE @cSection WHEN '1' THEN 'SRA.'
                                     WHEN '2' THEN 'CRO.'
                                     WHEN '3' THEN 'NINO' END,
            @cSeparate, @nBultoNo, @cTempBarcodeFrom, @cContact1, @cContact2)

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN PRINT_SHOPLBL
               WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN

               GOTO Quit
            END

            UPDATE dbo.CODELKUP WITH (ROWLOCK) SET
               UDF05 = CASE WHEN ISNULL(UDF05, '') = '' OR CAST(UDF05 AS INT) = 0 THEN CAST(UDF03 AS INT) + 1
                            WHEN CAST(ISNULL(UDF05, '') AS INT) + 1 > CAST(ISNULL(UDF04, '') AS INT) THEN CAST(UDF03 AS INT) + 1
                            ELSE CAST(UDF05 AS INT) + 1 END
            WHERE ListName = @cShopLabelType
            AND   UDF01 = RTRIM(@cSection)
            AND   StorerKey = RTRIM(@cStorerKey)
            AND   Long = RTRIM(@cShopNo)

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN PRINT_SHOPLBL
               WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN

               GOTO Quit
            END

            SET @nStorePrintQty = @nStorePrintQty - 1
         END

         FETCH NEXT FROM CUR_DETAIL INTO @cConsigneeKey, @cSeparate, @nStorePrintQty
      END
      CLOSE CUR_DETAIL
      DEALLOCATE CUR_DETAIL

   FETCH NEXT FROM CUR_HEADER INTO @cLOC, @cSKU, @cSection
   END
   CLOSE CUR_HEADER
   DEALLOCATE CUR_HEADER

   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

   SELECT * FROM #TEMP_SHOPLBL ORDER BY ID	--SOS307411

   Quit:
      DROP TABLE #TEMP_SHOPLBL

GO