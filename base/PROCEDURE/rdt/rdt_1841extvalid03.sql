SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/            
/* Store procedure: rdt_1841ExtValid03                                        */            
/* Copyright      : LF Logistics                                              */            
/*                                                                            */            
/* Purpose: Allow only 1 ASN 1 Lane 1 User                                    */            
/*                                                                            */            
/*                                                                            */            
/* Date        Rev  Author       Purposes                                     */            
/* 2021-10-27  1.0  Chermaine    WMS-18096. Created (dup rdt_1841ExtValid02)  */            
/******************************************************************************/            
            
CREATE PROCEDURE [RDT].[rdt_1841ExtValid03]            
   @nMobile        INT,            
   @nFunc          INT,            
   @cLangCode      NVARCHAR( 3),            
   @nStep          INT,            
   @nAfterStep     INT,            
   @nInputKey      INT,            
   @cFacility      NVARCHAR( 5),             
   @cStorerKey     NVARCHAR( 15),            
   @cReceiptKey    NVARCHAR( 10),            
   @cLane          NVARCHAR( 10),            
   @cUCC           NVARCHAR( 20),            
   @cToID          NVARCHAR( 18),            
   @cSKU           NVARCHAR( 20),            
   @nQty           INT,            
   @cOption        NVARCHAR( 1),                           
   @cPosition      NVARCHAR( 20),            
   @tExtValidVar   VariableTable READONLY,             
   @nErrNo         INT           OUTPUT,             
   @cErrMsg        NVARCHAR( 20) OUTPUT            
AS            
BEGIN            
   SET NOCOUNT ON            
   SET QUOTED_IDENTIFIER OFF            
   SET ANSI_NULLS OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
       
   DECLARE @cCond NVARCHAR(10)    
             
   IF @nStep = 2 -- UCC          
   BEGIN          
      IF @nInputKey = 1 -- ENTER          
      BEGIN                  
         -- Check UserDefine10 in OriLine ASN          
         IF NOT EXISTS( SELECT TOP 1 1           
                        FROM ReceiptDetail RD WITH (NOLOCK)          
                        JOIN UCC U WITH (NOLOCK) ON (RD.ExternReceiptKey = u.ExternKey AND RD.StorerKey = U.Storerkey)          
                        WHERE U.UccNo = @cUCC           
                        AND RD.ReceiptKey = @cReceiptKey          
                        AND RD.StorerKey = @cStorerKey )          
         BEGIN          
            SET @nErrNo = 177801          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC          
            GOTO Quit          
         END          
      END          
   END          
             
   IF @nStep = 4 -- ClosePallet          
   BEGIN          
      IF @nInputKey = 1 -- ENTER          
      BEGIN                  
       SELECT @cCond = Value FROM @tExtValidVar WHERE Variable = '@cCond'    
           
         IF @cToID = '99'          
         BEGIN          
            IF EXISTS (SELECT TOP 1 1          
                     FROM RDT.rdtPreReceiveSort PR WITH (NOLOCK)          
                     JOIN codelkup C WITH (NOLOCK) ON (C.LISTNAME = 'ADICLOSE' AND C.Storerkey = PR.storerKey AND PR.position = C.Code)          
                     --JOIN codelkup C WITH (NOLOCK) ON (C.Storerkey = PR.storerKey AND PR.position = C.Code)          
                     WHERE PR.StorerKey = @cStorerKey    
                     AND   ReceiptKey = @cReceiptKey          
                     AND   LOC = @cLane          
                     AND   [Status] = '1')          
            BEGIN          
               SET @nErrNo = 177802          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCloseByID           
               GOTO Quit          
            END        
                
            IF EXISTS (SELECT 1    
                        FROM rdt.rdtPreReceiveSort (NOLOCK)     
                        WHERE StorerKey = @cStorerKey    
                        AND   ReceiptKey = @cReceiptKey    
                        AND   LOC = @cLane    
                        AND   [Status] = '1'    
                        GROUP BY uccNo    
                        HAVING COUNT(uccNo) > 1 AND COUNT(DISTINCT SKU) > 1 )    
               AND EXISTS( SELECT 1 from codelkup (nolock)      
                          WHERE LISTNAME='ADIALLOWMX'    
                             AND Storerkey=@cStorerKey    
                             AND code='N')    
            BEGIN    
             SET @nErrNo = 177804          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ucc > 1 SKU        
               GOTO Quit     
            END                
         END            
         ELSE --by specific Pallet ID      
         BEGIN      
            IF EXISTS (SELECT 1    
                        FROM rdt.rdtPreReceiveSort (NOLOCK)     
                        WHERE StorerKey = @cStorerKey    
                        AND   ReceiptKey = @cReceiptKey    
                        AND   LOC = @cLane    
                        AND   ID = @cToID    
                        AND   [Status] = '1'    
                        GROUP BY uccNo    
                        HAVING COUNT(uccNo) > 1 AND COUNT(DISTINCT SKU) > 1 )    
               AND EXISTS( SELECT 1 from codelkup (nolock)     
                           WHERE LISTNAME='ADIALLOWMX'    
                              AND Storerkey=@cStorerKey    
                              AND code='N')    
            BEGIN    
               SET @nErrNo = 177805          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ucc > 1 SKU        
               GOTO Quit     
            END       
                
            IF EXISTS (SELECT TOP 1 1          
                              FROM RDT.rdtPreReceiveSort PR WITH (NOLOCK)          
                              JOIN codelkup C WITH (NOLOCK) ON (C.LISTNAME = 'ADICLOSE' AND C.Storerkey = PR.storerKey AND PR.position = C.Code AND C.UDF01 = 'Y')          
                              WHERE ReceiptKey = @cReceiptKey          
                              AND   LOC = @cLane          
                              AND   ID = @cToID          
                              AND   [Status] = '1')        
            BEGIN    
               --has not performed UCC Audit     
               --IF NOT EXISTS (SELECT 1    
               --               FROM rdt.rdtUccPreRcvAuditLog RA WITH (NOLOCK)    
               --               JOIN rdt.rdtPreReceiveSort PR WITH (NOLOCK) ON (RA.OrgUccNo = PR.UccNo AND RA.storerKey = PR.storerKey)    
               --               WHERE RA.storerKey = @cStorerKey    
               --               AND RA.STATUS = '9'    
               --               AND PR.ReceiptKey = @cReceiptKey    
               --               AND PR.LOC = @cLane          
               --               AND PR.ID = @cToID          
               --               AND PR.[Status] = '1')    
               IF EXISTS (SELECT 1        
                              FROM rdt.rdtPreReceiveSort PR WITH (NOLOCK)         
                              WHERE PR.storerKey = @cStorerKey        
                              AND PR.ReceiptKey = @cReceiptKey        
                              AND PR.LOC = @cLane              
                              AND PR.ID = @cToID              
                              AND PR.[Status] = '1'      
                              AND NOT EXISTS (SELECT 1 FROM rdt.rdtUccPreRcvAuditLog RA WITH (NOLOCK)        
                                                WHERE RA.storerKey = PR.storerKey      
                                                AND  RA.OrgUccNo = PR.UccNo      
                           AND  RA.STATUS = '9'))      
               BEGIN    
                  SET @nErrNo = 177806          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insp Not Done    
                  GOTO Quit     
               END                                  
            END    
                
            IF EXISTS (SELECT TOP 1 1          
                              FROM RDT.rdtPreReceiveSort PR WITH (NOLOCK)          
                              JOIN codelkup C WITH (NOLOCK) ON (C.LISTNAME = 'ADICLOSE' AND C.Storerkey = PR.storerKey AND PR.position = C.Code)          
                              WHERE ReceiptKey = @cReceiptKey          
                              AND   LOC = @cLane          
                              AND   ID = @cToID          
                              AND   [Status] = '1')          
            BEGIN          
               IF NOT EXISTS ( SELECT TOP 1 1          
                           FROM RDT.rdtPreReceiveSort PR WITH (NOLOCK)          
                           JOIN codelkup C WITH (NOLOCK) ON (C.LISTNAME = 'ADICLOSE' AND C.Storerkey = PR.storerKey AND PR.position = C.Code)          
                           WHERE ReceiptKey = @cReceiptKey          
                           AND   LOC = @cLane          
                           AND   ID = @cToID          
                           AND   c.Short = @cCond          
                           AND   [Status] = '1')          
                               
               BEGIN          
                  SET @nErrNo = 177803          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCond          
                  GOTO Quit          
               END             
            END           
         END             
      END          
   END          
          
   Quit:            
            
END  

GO