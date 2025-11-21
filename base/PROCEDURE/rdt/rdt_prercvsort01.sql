SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Store procedure: rdt_PreRcvSort01                                                   */
/*                                                                                     */
/* Purpose: Show pallet position                                                       */
/* 1.For mix sku ucc, always show position from codelkup short = 0 and code2 = facility*/
/* 2.For single sku ucc and total count of receiptgroup < storer.susr3,                */
/*   always show position from codelkup short = 1 and code2 = facility                 */
/* 3.For single sku ucc and total count of receiptgroup >= storer.susr3                */
/*   always show position with locationtype = 'SORT' and 1 position for 1 SKU+Facility */
/*                                                                                     */
/* Called from: rdtfnc_PreReceiveSort2                                                 */
/*                                                                                     */
/* Modifications log:                                                                  */
/*                                                                                     */
/* Date        Rev  Author     Purposes                                                */
/* 18-Jul-2017 1.0  James      WMS2289 - Created                                       */
/* 02-Jul-2018 1.1  James      WMS5493 - Show scanned/total cartons (james01)          */
/*                             Allow multi user sort into same loc (james02)           */
/***************************************************************************************/

CREATE PROC [RDT].[rdt_PreRcvSort01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cParam1          NVARCHAR( 20),
   @cParam2          NVARCHAR( 20),
   @cParam3          NVARCHAR( 20),
   @cParam4          NVARCHAR( 20),
   @cParam5          NVARCHAR( 20),
   @cUCCNo           NVARCHAR( 20),  
   @cPosition01      NVARCHAR( 20)  OUTPUT,   
   @cPosition02      NVARCHAR( 20)  OUTPUT,   
   @cPosition03      NVARCHAR( 20)  OUTPUT,   
   @cPosition04      NVARCHAR( 20)  OUTPUT,   
   @cPosition05      NVARCHAR( 20)  OUTPUT,   
   @cPosition06      NVARCHAR( 20)  OUTPUT,   
   @cPosition07      NVARCHAR( 20)  OUTPUT,   
   @cPosition08      NVARCHAR( 20)  OUTPUT,   
   @cPosition09      NVARCHAR( 20)  OUTPUT,   
   @cPosition10      NVARCHAR( 20)  OUTPUT,   
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT 
)
AS
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE 
      @cReceiptGroup NVARCHAR( 20),
      @cUCC_Facility NVARCHAR( 5),
      @cUCC_SKU      NVARCHAR( 20),
      @cLOC          NVARCHAR( 10), 
      @cLocType      NVARCHAR( 10), 
      @cReceiptKey   NVARCHAR( 10), 
      @nTranCount    INT,
      @nTTL_CtnCount INT,
      @nTTL2CtnCount INT,
      @nMultiSKUUCC  INT,
      @nRowref       INT,
      @nReleaseLOC   INT,
      @nMaxAllowedCtnPerPallet   INT,
      @cUserName     NVARCHAR( 18)

   DECLARE  @cErrMsg1    NVARCHAR( 20), 
            @cErrMsg2    NVARCHAR( 20),
            @cErrMsg3    NVARCHAR( 20), 
            @cErrMsg4    NVARCHAR( 20),
            @cErrMsg5    NVARCHAR( 20)
   /*
   Step:
   1. scan ucc
   2. check single or mix sku ucc

   2.1 mix sku:
   show loc 1, 2, 3. 1 loc 1 facility

   2.2 single sku:
   2.3 if total # of carton < susr3 
          display loc 3, 4, 5
       else 
          display dynamic loc based on facility + sku

   release loc after everything scanned within receiptgroup
   */

   SET @cReceiptGroup = @cParam1
   SET @cPosition01 = ''

   SELECT @cUserName = UserName 
   FROM RDT.RDTMobRec WITH (NOLOCK) 
   WHERE MOBILE = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_PreRcvSort01

   CREATE TABLE #Multis (
   RowRef   INT IDENTITY(1,1) NOT NULL,
   UCCNo    NVARCHAR(20)      NOT NULL)

   INSERT INTO #Multis (UCCNo)
   SELECT RD.UserDefine01 
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
   JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
   WHERE R.StorerKey = @cStorerKey
   AND   R.ReceiptGroup = @cReceiptGroup
   AND   R.Status < '9' 
   AND   R.ASNStatus <> 'CANC'
   GROUP BY RD.UserDefine01 
   HAVING COUNT( DISTINCT RD.SKU) > 1

   SELECT @nMaxAllowedCtnPerPallet = SUSR3 
   FROM dbo.Storer WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   [Type] = '1'

   SELECT @cUCC_Facility = R.Facility
   FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
   JOIN dbo.Receipt R WITH (NOLOCK) ON RD.ReceiptKey = R.ReceiptKey
   WHERE RD.StorerKey = @cStorerKey
   AND   RD.UserDefine01 = @cUCCNo

   -- Check if ucc has mix sku
   IF EXISTS ( SELECT 1 
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
               WHERE R.StorerKey = @cStorerKey
               AND   R.ReceiptGroup = @cReceiptGroup
               AND   R.Status < '9' 
               AND   R.ASNStatus <> 'CANC'
               AND   RD.UserDefine01 = @cUCCNo
               GROUP BY RD.UserDefine01 
               HAVING COUNT( DISTINCT RD.SKU) > 1)
   BEGIN
      SET @nMultiSKUUCC = 1

      -- Look for loc with same facility
      SELECT @cLOC = Code
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PRERCVSORT'
      AND   Code2 = @cUCC_Facility
      AND   Short = '0'
      AND   StorerKey = @cStorerKey
   END
   ELSE  -- single sku ucc
   BEGIN
      SET @nMultiSKUUCC = 0

      SELECT TOP 1 @cUCC_SKU = RD.SKU
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
      AND   R.ReceiptGroup = @cReceiptGroup
      AND   R.Status < '9' 
      AND   R.ASNStatus <> 'CANC'
      AND   RD.UserDefine01 = @cUCCNo

      SELECT @nTTL_CtnCount = COUNT( DISTINCT RD.UserDefine01) 
      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
      JOIN dbo.Receipt R WITH (NOLOCK) ON RD.ReceiptKey = R.ReceiptKey
      WHERE RD.StorerKey = @cStorerKey
      AND   RD.SKU = @cUCC_SKU
      AND   R.ReceiptGroup = @cReceiptGroup
      AND   R.Facility = @cUCC_Facility
      GROUP BY RD.SKU
      HAVING COUNT( DISTINCT SKU) = 1

      IF @nTTL_CtnCount <= @nMaxAllowedCtnPerPallet
      BEGIN
         -- Look for loc with same facility
         SELECT @cLOC = Code
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'PRERCVSORT'
         AND   Code2 = @cUCC_Facility
         AND   Short = '1'
         AND   StorerKey = @cStorerKey
         ORDER BY 1
      END
      ELSE
      BEGIN
         -- Look for loc with same sku + facility previously sorted
         SELECT TOP 1 @cLOC = LOC
         FROM rdt.rdtPreReceiveSort2Log WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UDF01 = @cReceiptGroup
         AND   Facility = @cUCC_Facility
         AND   SKU = @cUCC_SKU
         AND   [Status] = '0'

         IF ISNULL( @cLOC, '') = ''
         BEGIN
            -- Get the loc type of the type of the loc we are looking for next
            SELECT TOP 1 @cLocType = UDF01
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE ListName = 'PRERCVSORT'
            AND   StorerKey = @cStorerKey
            AND   Short = '1'
            AND   Code2 = @cUCC_Facility

            -- If previously not sorted then look for 1 loc with locationtype = 'SORT'
            SELECT TOP 1 @cLOC = LOC
            FROM dbo.LOC WITH (NOLOCK)
            WHERE Facility = @cUCC_Facility
            AND   LocationType = @cLocType
            AND   NOT EXISTS ( SELECT 1 
                               FROM rdt.rdtPreReceiveSort2Log RL WITH (NOLOCK)
                               WHERE RL.LOC = LOC.LOC
                               AND   [Status] = '0'
                               AND   RL.AddWho = @cUserName)  -- (james02)
            AND   NOT EXISTS ( SELECT 1 
                               FROM dbo.CODELKUP CLK WITH (NOLOCK)
                               WHERE CLK.CODE = LOC.LOC
                               AND   CLK.ListName = 'PRERCVSORT'
                               AND   CLK.StorerKey = @cStorerKey)
            ORDER BY 1
         END
      END
   END

   IF ISNULL( @cLOC, '') = ''
   BEGIN
      SET @nErrNo = 112501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Suggest Loc
      SET @cPosition01 = ''
      GOTO RollBackTran
   END
   ELSE
   BEGIN
      IF EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
                  WHERE LOC = @cLOC
                  AND   UDF01 <> @cReceiptGroup
                  AND   [Status] = '0'
                  AND   AddWho = @cUserName)
      BEGIN
         SET @nErrNo = 112502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Suggest Loc
         SET @cPosition01 = ''
         GOTO RollBackTran
      END

      IF NOT EXISTS ( SELECT 1 
                        FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   UCCNo = @cUCCNo
                        AND   UDF01 = @cReceiptGroup
                        AND   [Status] = '0')
      BEGIN
         IF @nMultiSKUUCC = 1
            INSERT INTO RDT.rdtPreReceiveSort2Log
            (Facility, StorerKey, ReceiptKey, UCCNo, SKU, LOC, UDF01, [Status], AddWho, AddDate, EditWho, EditDate)
            VALUES
            (@cUCC_Facility, @cStorerKey, '', @cUCCNo, 'MULTIS', @cLOC, @cReceiptGroup, '0', @cUserName, GETDATE(), @cUserName, GETDATE())
         ELSE
            INSERT INTO RDT.rdtPreReceiveSort2Log
            (Facility, StorerKey, ReceiptKey, UCCNo, SKU, LOC, UDF01, [Status], AddWho, AddDate, EditWho, EditDate)
            VALUES
            (@cUCC_Facility, @cStorerKey, '', @cUCCNo, @cUCC_SKU, @cLOC, @cReceiptGroup, '0', @cUserName, GETDATE(), @cUserName, GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 112503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Log Fail
            SET @cPosition01 = ''
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE RDT.rdtPreReceiveSort2Log WITH (ROWLOCK) SET 
            EditWho = @cUserName,
            EditDate = GETDATE()
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCCNo
         AND   UDF01 = @cReceiptGroup
         AND   [Status] = '0'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 112504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Log Fail
            SET @cPosition01 = ''
            GOTO RollBackTran
         END
      END
   END

   SET @cPosition01 = 'Position:'
   SET @cPosition02 = @cLOC

   SET @nTTL2CtnCount = 0
   SELECT @nTTL2CtnCount = COUNT( DISTINCT RD.UserDefine01) 
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
   JOIN dbo.Receipt R WITH (NOLOCK) ON RD.ReceiptKey = R.ReceiptKey
   WHERE RD.StorerKey = @cStorerKey
   AND   R.ReceiptGroup = @cReceiptGroup
   AND   R.Facility = @cUCC_Facility

   SET @nTTL_CtnCount = 0
   SELECT @nTTL_CtnCount = COUNT( DISTINCT UCCNo) 
   FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   UDF01 = @cReceiptGroup
   AND   [Status] = '0'

   SET @cPosition10 = 'SCANNED: ' + 
                        RTRIM( CAST( @nTTL_CtnCount AS NVARCHAR( 3))) + 
                        '/' + 
                        LTRIM( CAST( @nTTL2CtnCount AS NVARCHAR( 3)))

   -- Release loc by facility
   -- 1. Mix sku
   ----check all ucc with sku count > 1 in this facility + receiptgroup all already scanned? if yes then release else do nothing
   -- 2. Single sku
   ----Check all ucc with sku count = 1 in this facility + receiptgroup all already scanned? if yes then release else do nothing
   SET @nReleaseLOC = 0
   IF @nMultiSKUUCC = '1'
   BEGIN
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                      JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
                      WHERE R.StorerKey = @cStorerKey
                      AND   R.ReceiptGroup = @cReceiptGroup
                      AND   R.Status < '9' 
                      AND   R.ASNStatus <> 'CANC'
                      AND   R.Facility = @cUCC_Facility
                      AND   ISNULL( RD.UserDefine01, '') <> ''
                      AND   NOT EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort2Log RL WITH (NOLOCK)
                                         WHERE RL.UCCNo = RD.UserDefine01
                                         AND   RL.UDF01 = R.ReceiptGroup
                                         AND   RL.StorerKey = R.StorerKey
                                         AND   RL.Facility = R.Facility
                                         AND   RL.SKU = 'MULTIS')
                  GROUP BY RD.UserDefine01 
                  HAVING COUNT( DISTINCT RD.SKU) > 1)
      BEGIN
         SET @nReleaseLOC = 1
      END
   END
   ELSE
   BEGIN
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                      JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
                      WHERE R.StorerKey = @cStorerKey
                      AND   R.ReceiptGroup = @cReceiptGroup
                      AND   R.Status < '9' 
                      AND   R.ASNStatus <> 'CANC'
                      AND   R.Facility = @cUCC_Facility
                      AND   RD.Sku = @cUCC_SKU
                      AND   ISNULL( RD.UserDefine01, '') <> ''
                      AND   NOT EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort2Log RL WITH (NOLOCK)
                                         WHERE RL.UCCNo = RD.UserDefine01
                                         AND   RL.UDF01 = R.ReceiptGroup
                                         AND   RL.StorerKey = R.StorerKey
                                         AND   RL.Facility = R.Facility
                                         AND   RL.SKU = RD.Sku)
                      AND   NOT EXISTS ( SELECT 1 FROM #Multis M WHERE RD.UserDefine01 = M.UCCNo)
                  GROUP BY RD.UserDefine01 
                  HAVING COUNT( DISTINCT RD.SKU) = 1)
      BEGIN
         SET @nReleaseLOC = 1
      END
   END

   IF @nReleaseLOC = 1
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT ROWREF FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
      WHERE UDF01 = @cReceiptGroup
      AND   LOC = @cLOC
      AND   Facility = @cUCC_Facility
      AND   [Status] = '0'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowref
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE RDT.rdtPreReceiveSort2Log WITH (ROWLOCK) SET 
            [Status] = '9',
            EditDate = GETDATE(),
            EditWho = @cUserName
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 112505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Rel Loc Fail
            SET @cPosition01 = ''
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO RollBackTran
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowref
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   SELECT TOP 1 @cReceiptKey = R.ReceiptKey
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
   JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
   WHERE R.StorerKey = @cStorerKey
   AND   R.ReceiptGroup = @cReceiptGroup
   AND   RD.UserDefine01 = @cUCCNo
   ORDER BY 1

   IF NOT EXISTS ( SELECT 1 
                   FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                   JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
                   WHERE R.StorerKey = @cStorerKey
                   AND   R.ReceiptGroup = @cReceiptGroup
                   AND   R.ReceiptKey = @cReceiptKey
                   AND   NOT EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort2Log RL WITH (NOLOCK)
                                      WHERE RL.UCCNo = RD.UserDefine01
                                      AND   RL.UDF01 = R.ReceiptGroup
                                      AND   RL.StorerKey = R.StorerKey
                                      AND   RL.Facility = R.Facility))
   BEGIN
      SET @nErrNo = 0
      SET @cErrMsg1 = rdt.rdtgetmessage( 112506, @cLangCode, 'DSP') 
      SET @cErrMsg2 = @cReceiptKey
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
      IF @nErrNo = 1
      BEGIN
         SET @cErrMsg1 = ''
         SET @cErrMsg2 = ''
      END
   END

   -- Last SKU in ASN, 1 receiptgroup only 1 SKU exists in ASN
   IF @nMultiSKUUCC = 0 AND @nReleaseLOC = 1
   BEGIN
      SET @nErrNo = 0
      SET @cErrMsg1 = rdt.rdtgetmessage( 112507, @cLangCode, 'DSP') 
      SET @cErrMsg2 = @cUCC_SKU
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cPosition01, @cPosition02
      IF @nErrNo = 1
      BEGIN
         SET @cErrMsg1 = ''
         SET @cErrMsg2 = ''
         SET @cErrMsg3 = ''
         SET @cErrMsg4 = ''
      END
   END

   /*
   -- Check if everything received, if yes then need to release the loc
   IF EXISTS ( SELECT 1 FROM ReceiptDetail RD WITH (NOLOCK)
               JOIN dbo.Receipt R WITH (NOLOCK) ON RD.ReceiptKey = R.ReceiptKey
               WHERE R.StorerKey = @cStorerKey
               AND   R.ReceiptGroup = @cReceiptGroup
               AND   ISNULL( RD.UserDefine01, '') <> ''
               AND   NOT EXISTS ( SELECT 1 FROM RDT.rdtPreReceiveSort2Log RL WITH (NOLOCK)
               WHERE RL.UCCNo = RD.UserDefine01
               AND   RL.UDF01 = R.ReceiptGroup
               AND   RL.StorerKey = R.StorerKey
               AND   RL.Status = '0'))
      GOTO Quit
   ELSE
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT ROWREF FROM RDT.rdtPreReceiveSort2Log WITH (NOLOCK)
      WHERE UDF01 = @cReceiptGroup
      AND   [Status] = '0'
      OPEN CUR_UPD
      FETCH NEXT FROM CUR_UPD INTO @nRowref
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE RDT.rdtPreReceiveSort2Log WITH (ROWLOCK) SET 
            [Status] = '9',
            EditDate = GETDATE(),
            EditWho = sUser_sName()
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 112505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Rel Loc Fail
            SET @cPosition = ''
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO RollBackTran
         END

         FETCH NEXT FROM CUR_UPD INTO @nRowref
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END   
   */
   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_PreRcvSort01
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

SET QUOTED_IDENTIFIER OFF

GO