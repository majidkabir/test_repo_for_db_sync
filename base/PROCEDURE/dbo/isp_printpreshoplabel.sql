SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: isp_PrintPreShopLabel                                    */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#257607 - Print Pre Shop label                                */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2012-10-05 1.0  James    Created                                          */
/* 2012-11-28 1.1  James    Enhancement (james01)                            */
/* 2013-05-08 1.2  James    SOS276805 - Fix print seq (james02)              */
/* 2013-08-27 1.3  James    SOS287522 - Label format change (james03)        */
/* 2013-10-30 1.4  James    SOS293347 - Add label type (james04)             */
/* 2014-04-04 1.5  James    SOS307345 - Add custom sp to build label(james01)*/
/* 2015-03-04 1.6  Audrey   SOS332213 - Ordery by Bulto             (ang01)  */
/*****************************************************************************/
CREATE PROC [dbo].[isp_PrintPreShopLabel](
   @cStorerKey       NVARCHAR( 15),
   @cDistCenter      NVARCHAR( 6),  -- (james03)
   @cSection         NVARCHAR( 5),
   @cShopNo          NVARCHAR( 6),  -- (james03)
   @cSeparate        NVARCHAR( 5),
   @cPrintQty        NVARCHAR( 5),
   @cShopLabelType   NVARCHAR( 10)  -- (james04)
) AS

Declare
   @cBultoNo         NVARCHAR( 5),
   @cBulto           NVARCHAR( 5),
   @cMinBultoNo      NVARCHAR( 5),
   @cMaxBultoNo      NVARCHAR( 5),
   @cUDF03           NVARCHAR( 30),
   @cUDF04           NVARCHAR( 30),
   @cCode            NVARCHAR( 30),
   @cTempBarcodeFrom NVARCHAR( 20),
   @cCheckDigit      NVARCHAR( 1),
   @cLangCode        NVARCHAR( 3),
   @cConsigneeKey    NVARCHAR( 15)

DECLARE
   @nTranCount       INT,
   @nBultoNo         INT,
   @nNewBultoNo      INT

DECLARE @cBuildLabelNo  NVARCHAR( 20),
        @cLabelNo_Out   NVARCHAR( 20),
        @cLoadKey       NVARCHAR( 10),
        @cLabelType     NVARCHAR( 10),
        @bSuccess       INT,
        @nErrNo         INT,
        @cErrMsg        NVARCHAR( 20)

DECLARE @nPrintQty   INT
SET @nPrintQty = CAST(@cPrintQty AS INT)

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN PRINT_SHOPLBL

   SELECT @cLangCode = Lang_Code FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = sUser_sName()
   IF ISNULL(@cLangCode, '') = ''
      SET @cLangCode = 'ENG'

   SET @cConsigneeKey = 'ITX' + REPLACE(LTRIM(REPLACE(@cShopNo, '0', ' ')), ' ', '0')

   CREATE TABLE #TEMP_SHOPLBL
   (  Company     NVARCHAR( 45) NULL,
      Address1    NVARCHAR( 45) NULL,
      Address2    NVARCHAR( 45) NULL,
      Address3    NVARCHAR( 45) NULL,
      Address4    NVARCHAR( 45) NULL,
      Zip         NVARCHAR( 18) NULL,
      City        NVARCHAR( 45) NULL,
      ShopNo      NVARCHAR( 5),
      Section     NVARCHAR( 5),
      Separate    NVARCHAR( 5),
      Bulto       NVARCHAR( 5),
      Contact1    NVARCHAR( 30) NULL,
      Contact2    NVARCHAR( 30) NULL,
      Barcode     NVARCHAR( 30) )

   WHILE @nPrintQty > 0
   BEGIN
      IF EXISTS (SELECT 1
                 FROM dbo.CODELKUP WITH (NOLOCK)
                 WHERE ListName = @cShopLabelType--'LABELNO'
                 AND   UDF01 = RTRIM(@cSection)
                 AND   StorerKey = RTRIM(@cStorerKey)
                 AND   Long = RTRIM(@cShopNo))
      BEGIN
         SELECT @cBultoNo = UDF05,
                @cMinBultoNo = UDF03,
                @cMaxBultoNo = UDF04
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = @cShopLabelType--'LABELNO'
         AND   UDF01 = RTRIM(@cSection)
         AND   StorerKey = RTRIM(@cStorerKey)
         AND   Long = RTRIM(@cShopNo)

         -- 1st time setup or data error then reset
         IF ISNULL(@cBultoNo, '') = '' OR @cBultoNo = '0'
         BEGIN
            SET @nBultoNo = CAST(@cMinBultoNo AS INT) + 1
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
         -- If not exists then copy from same storer + udf01 + udf02
         SELECT TOP 1
            @cUDF03 = UDF03,
            @cUDF04 = UDF04
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = @cShopLabelType--'LABELNO'
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
         WHERE ListName = @cShopLabelType--'LABELNO'
         AND   StorerKey = RTRIM(@cStorerKey)
         GROUP BY CODE
         ORDER BY CODE DESC

         SET @nBultoNo = CAST(@cUDF03 AS INT) + 1
         SET @nNewBultoNo = CAST(@cUDF03 AS INT)

         -- Insert new entry if record not exists (unique key listname + storerkey + udf01 + udf02 + long)
         INSERT INTO dbo.CODELKUP (ListName, Code, Long, StorerKey,
                      UDF01, UDF02, UDF03, UDF04, UDF05)
         --VALUES ('LABELNO', @cCode, @cShopNo, @cStorerKey,
         VALUES (@cShopLabelType, @cCode, @cShopNo, @cStorerKey,
                 @cSection, @cSeparate, @cUDF03, @cUDF04, @nNewBultoNo)

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN PRINT_SHOPLBL
            WHILE @@TRANCOUNT > @nTranCount
               COMMIT TRAN
            GOTO Quit
         END
      END
      /*
      -- (james03)
      SET @cTempBarcodeFrom = ''
      SET @cTempBarcodeFrom = SUBSTRING(@cDistCenter, 1, 4)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '0000' + RTRIM(LTRIM(@cShopNo)), 4)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSection, 1, 1)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSeparate, 1, 1)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '00000' + CAST( @nBultoNo AS NVARCHAR( 5)), 5)
      SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcodeFrom), 0)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + @cCheckDigit
      */

      SET @cBuildLabelNo = ''
      SET @cBuildLabelNo = rdt.RDTGetConfig( 590, 'BuildLabelNo', @cStorerkey)

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

      INSERT INTO #TEMP_SHOPLBL
      (Company, Address1, Address2, Address3, Address4, Zip, City, ShopNo, Section, Separate, Bulto, Contact1, Contact2, Barcode)
      SELECT
         Company,
         Address1,
         Address2,
         Address3,
         Address4,
         Zip,
         City,
         @cShopNo AS ShopNo,
         CASE @cSection WHEN '1' THEN 'SRA.'
                        WHEN '2' THEN 'CRO.'
                        WHEN '3' THEN 'NINO'
                        END AS Section,
         @cSeparate AS Separate,
         @nBultoNo AS Bulto,
         Contact1,
         Contact2,
         @cTempBarcodeFrom AS Barcode
      FROM dbo.Storer WITH (NOLOCK)
      WHERE StorerKey = @cConsigneeKey
      AND   Type = '2'

      SET @nPrintQty = @nPrintQty - 1

      UPDATE dbo.CODELKUP WITH (ROWLOCK) SET
         UDF05 = CASE WHEN ISNULL(UDF05, '') = '' OR CAST(UDF05 AS INT) = 0 THEN CAST(UDF03 AS INT) + 1
                      WHEN CAST(ISNULL(UDF05, '') AS INT) + 1 > CAST(ISNULL(UDF04, '') AS INT) THEN CAST(UDF03 AS INT) + 1
                      ELSE CAST(UDF05 AS INT) + 1 END
      WHERE ListName = @cShopLabelType--'LABELNO'
      AND   UDF01 = RTRIM(@cSection)
      AND   StorerKey = RTRIM(@cStorerKey)
      AND   Long = RTRIM(@cShopNo)
   END

   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

   SELECT * FROM #TEMP_SHOPLBL
   Order by Bulto--ang01

   Quit:
      DROP TABLE #TEMP_SHOPLBL



GO