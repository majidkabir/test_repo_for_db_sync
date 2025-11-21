SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_573DefaultLOC01                                 */  
/* Copyright: LF Logistics                                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2022-02-10 1.0   YeeKung    WMS-23108 Created                        */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_573DefaultLOC01] (
   @nMobile       INT, 
   @nFunc         INT, 
   @cLangCode     NVARCHAR(3), 
   @nStep         INT, 
   @cStorerKey    NVARCHAR(15),
   @cFacility     NVARCHAR(5), 
   @cReceiptKey1  NVARCHAR(20),          
   @cReceiptKey2  NVARCHAR(20),          
   @cReceiptKey3  NVARCHAR(20),          
   @cReceiptKey4  NVARCHAR(20),          
   @cReceiptKey5  NVARCHAR(20),          
   @cLoc          NVARCHAR(20),           
   @cID           NVARCHAR(18),           
   @cUCC          NVARCHAR(20),
   @cDefaultToLoc NVARCHAR(20) OUTPUT,
   @nErrNo        INT          OUTPUT,            
   @cErrMsg       NVARCHAR(20) OUTPUT
)  
AS  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cLOC1 NVARCHAR(20)
   DECLARE @cLOC2 NVARCHAR(20)
   DECLARE @cLOC3 NVARCHAR(20)
   DECLARE @cLOC4 NVARCHAR(20)
   DECLARE @cLOC5 NVARCHAR(20)
   
   IF @nFunc = 573 -- UCC inbound receiving
   BEGIN

      IF ISNULL(@cReceiptKey1,'')<>''
      BEGIN
         SELECT @cLOC1 = short
         FROM Codelkup (NOLOCK)
         Where Storerkey = @cStorerkey
            AND Listname = '573ADDLGC'
            AND code IN (  SELECT userdefine01
                           FROM Receipt (nolock)
                           WHERE Receiptkey IN (@cReceiptKey1)
                              And Storerkey = @cStorerkey)

         IF ISNULL( @cLOC1,'') =''
         BEGIN
            SELECT @cLOC1 = short
            FROM Codelkup (NOLOCK)
            Where Storerkey = @cStorerkey
               AND Listname = '573ADDLGC'
               AND code = 'DEFAULT'
         END
      END
      IF ISNULL(@cReceiptKey2,'')<>''
      BEGIN
         SELECT @cLOC2 = short
         FROM Codelkup (NOLOCK)
         Where Storerkey = @cStorerkey
            AND Listname = '573ADDLGC'
            AND code IN (  SELECT userdefine01
                           FROM Receipt (nolock)
                           WHERE Receiptkey IN (@cReceiptKey2)
                              And Storerkey = @cStorerkey)

         IF ISNULL( @cLOC2,'') =''
         BEGIN
            SELECT @cLOC2 = short
            FROM Codelkup (NOLOCK)
            Where Storerkey = @cStorerkey
               AND Listname = '573ADDLGC'
               AND code = 'DEFAULT'
         END

         IF @cLOC1 <> @cLOC2
         BEGIN
            SET @nErrNo = 205401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO QUIT
         END
      END

      IF ISNULL(@cReceiptKey3,'')<>''
      BEGIN
         SELECT @cLOC3 = short
         FROM Codelkup (NOLOCK)
         Where Storerkey = @cStorerkey
            AND Listname = '573ADDLGC'
            AND code IN (  SELECT userdefine01
                           FROM Receipt (nolock)
                           WHERE Receiptkey IN (@cReceiptKey3)
                              And Storerkey = @cStorerkey)

         IF ISNULL( @cLOC3,'') =''
         BEGIN
            SELECT @cLOC3 = short
            FROM Codelkup (NOLOCK)
            Where Storerkey = @cStorerkey
               AND Listname = '573ADDLGC'
               AND code = 'DEFAULT'
         END

         IF @cLOC1 <> @cLOC3
         BEGIN
            SET @nErrNo = 97451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO QUIT
         END
      END
      IF ISNULL(@cReceiptKey4,'')<>''
      BEGIN
         SELECT @cLOC4 = short
         FROM Codelkup (NOLOCK)
         Where Storerkey = @cStorerkey
            AND Listname = '573ADDLGC'
            AND code IN (  SELECT userdefine01
                           FROM Receipt (nolock)
                           WHERE Receiptkey IN (@cReceiptKey4)
                              And Storerkey = @cStorerkey)

         IF ISNULL( @cLOC4,'') =''
         BEGIN
            SELECT @cLOC4 = short
            FROM Codelkup (NOLOCK)
            Where Storerkey = @cStorerkey
               AND Listname = '573ADDLGC'
               AND code = 'DEFAULT'
         END

         IF @cLOC1 <> @cLOC4
         BEGIN
            SET @nErrNo = 97451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO QUIT
         END
      END
      IF ISNULL(@cReceiptKey5,'')<>''
      BEGIN
         SELECT @cLOC5 = short
         FROM Codelkup (NOLOCK)
         Where Storerkey = @cStorerkey
            AND Listname = '573ADDLGC'
            AND code IN (  SELECT userdefine01
                           FROM Receipt (nolock)
                           WHERE Receiptkey IN (@cReceiptKey5)
                              And Storerkey = @cStorerkey)

         IF ISNULL( @cLOC5,'') =''
         BEGIN
            SELECT @cLOC5 = short
            FROM Codelkup (NOLOCK)
            Where Storerkey = @cStorerkey
               AND Listname = '573ADDLGC'
               AND code = 'DEFAULT'
         END

         IF @cLOC1 <> @cLOC5
         BEGIN
            SET @nErrNo = 97451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PTL Fail
            GOTO QUIT
         END
      END

      SET @cDefaultToLoc = @cLOC1

   END
   
Quit:  

GO