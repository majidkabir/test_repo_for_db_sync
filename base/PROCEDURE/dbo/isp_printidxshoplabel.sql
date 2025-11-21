SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: isp_PrintIDXShopLabel                                    */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: SOS#273078 - Print IDX Shop label                                */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2013-04-01 1.0  James    Created                                          */  
/* 2013-08-27 1.1  James    SOS287522 - Fix printing seq & label format      */
/*                          change (james01)                                 */
/* 2013-10-31 1.2  James    SOS294060 - Add Label type (james02)             */
/*****************************************************************************/  
  
CREATE PROC [dbo].[isp_PrintIDXShopLabel]( 
   @cStorerKey       NVARCHAR( 15), 
   @cLoadKey         NVARCHAR( 10), 
   @cLOC             NVARCHAR( 10), 
   @cSKU             NVARCHAR( 20), 
   @cSection         NVARCHAR( 5), 
   @cShopLabelType   NVARCHAR( 10)  -- (james02)
) AS  
  
Declare 
   @cConsigneeKey       NVARCHAR( 15),
   @cSeparate           NVARCHAR( 5),
   @cBultoNo            NVARCHAR( 5), 
   @cMaxBultoNo         NVARCHAR( 5),
   @cMinBultoNo         NVARCHAR( 5),
   @cUDF03              NVARCHAR( 30),
   @cUDF04              NVARCHAR( 30),
   @cCode               NVARCHAR( 30),
   @cTempBarcodeFrom    NVARCHAR( 20),
   @cDistCenter         NVARCHAR( 5),  -- (james01)
   @cShopNo             NVARCHAR( 5),  -- (james01)
   @cCheckDigit         NVARCHAR( 1), 
   @nBultoNo            INT, 
   @nStorePrintQty      INT, 
   @nNewBultoNo         INT, 
   @nTranCount          INT 

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN
   SAVE TRAN PRINT_SHOPLBL

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
      Barcode     NVARCHAR( 30), 
      Contact1    NVARCHAR( 30) NULL, 
      Contact2    NVARCHAR( 30) NULL,
      LOC         NVARCHAR( 10) ,
      SKU         NVARCHAR( 20) )

/*
   SELECT @cDistCenter = SUSR1 
   FROM dbo.Storer WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
*/
   SELECT @cDistCenter = ISNULL( UDF01, '')    -- (james02)
   FROM dbo.CodeLkUp WITH (NOLOCK) 
   WHERE ListName = 'SHPLBLTYPC'
   AND   Short = @cShopLabelType
   AND   StorerKey = @cStorerKey
      
   SET @cDistCenter = RIGHT( '0000' + RTRIM(LTRIM(@cDistCenter)), 4)
      
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
               WHERE ListName = @cShopLabelType--'LABELNO'
               AND   UDF01 = RTRIM(@cSection)
               AND   StorerKey = RTRIM(@cStorerKey)
            END
            ELSE
            BEGIN
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
              
         SET @cTempBarcodeFrom = ''
         SET @cTempBarcodeFrom = SUBSTRING(@cDistCenter, 1, 4)
         SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '0000' + RTRIM(LTRIM(@cShopNo)), 4)
         SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSection, 1, 1)
         SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSeparate, 1, 1)
         SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '00000' + CAST( @nBultoNo AS NVARCHAR( 5)), 5)
         SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcodeFrom), 0)
         SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + @cCheckDigit

         INSERT INTO #TEMP_SHOPLBL 
         (Company, Address1, Address2, Address3, Address4, Zip, City, ShopNo, Section, Separate, Bulto, Barcode, Contact1, Contact2, LOC, SKU)
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
            SUBSTRING(@cTempBarcodeFrom, 11, 5) AS Bulto, 
            @cTempBarcodeFrom AS Barcode, 
            Contact1, 
            Contact2, 
            @cLOC AS LOC, 
            @cSKU AS SKU                    
         FROM dbo.Storer WITH (NOLOCK) 
         WHERE StorerKey = @cConsigneeKey 
         AND   Type = '2'

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
         WHERE ListName = @cShopLabelType--'LABELNO'
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

   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN   

   SELECT * FROM #TEMP_SHOPLBL

   Quit:
      DROP TABLE #TEMP_SHOPLBL    


GO