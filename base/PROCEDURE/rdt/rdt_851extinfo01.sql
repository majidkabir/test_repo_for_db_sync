SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt.rdt_851ExtInfo01                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2023-02-17 1.0  yeekung  WMS-21563 Created                           */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_851ExtInfo01]
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tExtInfo       VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT, 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @cSQL             NVARCHAR(1000),   
   @cSQLParam        NVARCHAR(1000) 

   DECLARE @nCount            INT
   DECLARE @nRowCount         INT

   DECLARE @cErrMsg01         NVARCHAR( 20)
   DECLARE @cErrMsg02         NVARCHAR( 20)
   DECLARE @cErrMsg03         NVARCHAR( 20)
   DECLARE @cErrMsg04         NVARCHAR( 20)
   DECLARE @cErrMsg05         NVARCHAR( 20)
   
   DECLARE @cRefNo        NVARCHAR( 20)

   DECLARE @nPSKU           INT
   DECLARE @nPQTY           INT
   DECLARE @nCSKU           INT
   DECLARE @nCQTY           INT

   DECLARE @nPPAQTY          INT
   DECLARE @nPickQTY        INT

   -- Variable mapping
   SELECT @cRefNo = Value FROM @tExtInfo WHERE Variable = '@cRefNo'

   IF @nFunc = 851-- PPA by refno
   BEGIN
      IF @nStep = 3 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ESC
         BEGIN

            SELECT @nPickQTY=SUM(PD.qty)
            FROM ORDERS  O(NOLOCK)
            JOIN Pickdetail PD (NOLOCK) ON O.orderkey =PD.orderkey
            WHERE O.trackingno=@cRefNo
               AND O.storerkey=@cstorerkey

            SELECT @nPPAQTY=SUM(PPA.cqty)
            FROM RDT.RDTPPA PPA(NOLOCK)
            WHERE PPA.Refkey=@cRefNo
               AND PPA.storerkey=@cstorerkey

            IF (@nPPAQTY= @nPickQTY)
            BEGIN
               SET @nErrNo = 196951
               SET @cExtendedInfo=rdt.rdtgetmessage( 196901, @cLangCode,'DSP') --TaskFinish
            END

         END
         IF @nInputKey = 0 -- ESC
         BEGIN

            SELECT @nPSKU = COUNT( DISTINCT PD.SKU),
                     @nPQTY = ISNULL( SUM( PD.QTY), 0)
            FROM ORDERS  O(NOLOCK)
            JOIN Pickdetail PD (NOLOCK) ON O.orderkey =PD.orderkey
            WHERE O.trackingno=@cRefNo
               AND O.storerkey=@cstorerkey

            SELECT @nCSKU = COUNT( DISTINCT SKU),
                   @nCQTY = ISNULL( SUM( CQTY), 0)
            FROM RDT.RDTPPA PPA WITH (NOLOCK)
            WHERE PPA.Refkey = @cRefNo
               AND PPA.storerkey=@cstorerkey

            SET @nCQTY = CASE WHEN ISNULL(@nCQTY,'')='' THEN 0 ELSE @nCQTY END

            SET @cErrMsg01 = 'RefNo: ' + @cRefNo
            SET @cErrMsg02 = ''
            SET @cErrMsg03 = 'SKU CKD: ' + RTRIM( CAST( @nCSKU AS NVARCHAR( 2))) + '/' + RTRIM( CAST( @nPSKU AS NVARCHAR( 2)))
            SET @cErrMsg04 = 'QTY CKD: ' + RTRIM( CAST( @nCQTY AS NVARCHAR( 5))) + '/' + RTRIM( CAST( @nPQTY AS NVARCHAR( 5)))
            --insert into traceinfo (tracename, timein, col1, col2, col3, col4) values
            --('855', getdate(), @nCSKU, @nPSKU, @nCQTY, @nPQTY)

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
               @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05

            SET @nErrNo = 0
            SET @cErrMsg = ''
         END
      END
   END
   
Quit:
   
END

GO