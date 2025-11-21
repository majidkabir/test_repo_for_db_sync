SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_627ExtInfo01                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-12-13 1.0  YeeKung    SOS320585. Created                        */
/* 2018-03-08 1.1  Ung        RDT message                               */
/* 2018-07-27 1.2  Ung        Performance tuning                        */
/* 2020-01-09 1.2  KuanYee    INC1001390  Show LOC having Qty (KY01)    */  
/* 2020-03-20 1.3  James      WMS-12577 Show newest serialno record     */
/*                            (max serialnokey) (james01)               */
/* 2023-12-06 1.4  James      WMS24256 Fix Loc not display full(james02)*/
/* 2024-10-09 1.5  ShaoAn     WMS821 add Lottable02 display			    */
/************************************************************************/

CREATE   PROC [RDT].[rdt_627ExtInfo01] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT, 
   @nInputKey     INT, 
   @cStorerkey    NVARCHAR( 15), 
   @cSKU          NVARCHAR( 20),
   @cID           NVARCHAR( 20),
   @cSerialNo     NVARCHAR( 20),
   @cExtendedInfo1 NVARCHAR( 20) OUTPUT,
   @cExtendedInfo2 NVARCHAR( 20) OUTPUT,
   @cExtendedInfo3 NVARCHAR( 20) OUTPUT,
   @cExtendedInfo4 NVARCHAR( 20) OUTPUT,
   @cExtendedInfo5 NVARCHAR( 20) OUTPUT,
   @cExtendedInfo6 NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSNStatus NVARCHAR (20), 
           @cStatus NVARCHAR (20)
            
   IF @nFunc = 627 -- Serial No
   BEGIN
      IF @nStep = 1 -- SERIALNO
      BEGIN
         -- (james01)
         SELECT TOP 1 
            @cStatus=Status, 
            @cSNStatus= ExternStatus
         FROM dbo.SERIALNO WITH (NOLOCK)
         WHERE SerialNo = @cSerialNo 
         AND   SKU = @cSKU
         ORDER BY SerialNoKey DESC  
         
         IF @cStatus = NULL OR @cStatus = ''
         BEGIN
            SET @cExtendedInfo1='Status:  ';
         END
         ELSE 
         BEGIN
            SET @cExtendedInfo1='Status: '+CAST(@cStatus AS NVARCHAR(20));
         END

         IF @cSNStatus = NULL OR @cSNStatus = ''
         BEGIN
            SET @cExtendedInfo2='Extern Status:  ';
         END
         ELSE 
         BEGIN
            SET @cExtendedInfo2='Extern Status: '+CAST(@cSNStatus AS NVARCHAR(20));
         END

         -- Get Loc Info
         DECLARE @cLoc NVARCHAR(10);

         /*
         SELECT TOP 1 @cLoc=Loc 
         FROM lotxlocxid a WITH (NOLOCK) 
         JOIN SERIALNO b WITH (NOLOCK) ON a.id=b.id 
         AND a.sku=b.sku AND a.storerkey=b.storerkey
         WHERE a.sku=@cSKU AND a.id=@cid;
         */
         
         SELECT TOP 1 
            @cLOC = LOC 
         FROM LOTxLOCxID LLI WITH (NOLOCK) 
            JOIN SerialNo SN WITH (NOLOCK) ON (LLI.StorerKey = SN.StorerKey AND LLI.SKU = SN.SKU AND LLI.ID = SN.ID)
         WHERE LLI.StorerKey = @cStorerKey
            AND LLI.SKU = @cSKU 
            AND LLI.ID = @cID
            Group BY LLI.LOC               --(KY01)
            HAVING SUM(LLI.QTY) > '0'      --(KY01)
            ORDER BY LLI.LOC               --(KY01)

         SET @cExtendedInfo3 = rdt.rdtgetmessage( 120851, @cLangCode, 'DSP') --DYSON LOC: 

         IF @cLoc <> ''
            IF @cStatus IN ('1', 'H')
               SET @cExtendedInfo3 = RTRIM( @cExtendedInfo3) +  @cLoc
      END
   END




GO