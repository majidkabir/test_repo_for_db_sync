SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1849ExtValidSP01                                */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-11-02 1.0  YeeKung    WMS-15379 Created                         */  
/************************************************************************/  
CREATE PROC [RDT].[rdt_1849ExtValidSP01] (  
    @nMobile         INT,           
    @nFunc           INT,           
    @cLangCode       NVARCHAR( 3),  
    @nStep           INT,           
    @nInputKey       INT, 
    @cTaskdetailKey   NVARCHAR( 10),          
    @cTaskdetailKey1  NVARCHAR( 10),
    @cTaskdetailKey2  NVARCHAR( 10),
    @cTaskdetailKey3  NVARCHAR( 10),
    @cTaskdetailKey4  NVARCHAR( 10),
    @cFinalLOC       NVARCHAR( 10), 
    @nErrNo          INT OUTPUT,    
    @cErrMsg         NVARCHAR( 20) OUTPUT
)  
AS  

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
  
IF @nFunc = 1849  
BEGIN  
   IF @nStep in(0,2)
   BEGIN

      DECLARE @nPND_LOC1 NVARCHAR(10)
      DECLARE @nPND_LOC2 NVARCHAR(10)
      DECLARE @nPND_LOC3 NVARCHAR(10)
      DECLARE @nPND_LOC4 NVARCHAR(10)
      DECLARE @nPalletCount INT
      DECLARE @ctaskdetailkeyloop NVARCHAR(10)
      DECLARE @clocloop NVARCHAR(10)
      DECLARE @nCounter INT =0

      DECLARE PalletLoc CURSOR FOR  
      SELECt taskdetailkey,toloc
      from taskdetail (nolock)
      where taskdetailkey in (@ctaskdetailkey1,@ctaskdetailkey2,@ctaskdetailkey3,@ctaskdetailkey)

      open PalletLoc
      FETCH NEXT FROM PalletLoc 
      INTO @ctaskdetailkeyloop,@clocloop
      while (@@FETCH_STATUS=0)
      BEGIN
      
         select @nPalletCount=count(1)
         from lotxlocxid(nolock)
         where loc=@clocloop
         and qty<>0

         If @nCounter =0
         BEGIN
            IF EXISTS(SELECT 1
               FROM LOC L (NOLOCK) 
               WHERE L.loc=@clocloop
               group by Maxpallet
               HAVING @nPalletCount+1>L.Maxpallet)
            BEGIN
               SET @nErrNo = 160408
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MaxPalletINPND
               GOTO STEP_FAIL
            END

            SET @nPND_LOC1=@clocloop
         END

         If @nCounter =1
         BEGIN
            IF (@nPND_LOC1=@clocloop)
            BEGIN
               IF EXISTS(SELECT 1
                  FROM LOC L (NOLOCK) 
                  WHERE L.loc=@nPND_LOC1
                  group by Maxpallet
                  HAVING @nPalletCount+2>L.Maxpallet)
               BEGIN
                  SET @nErrNo = 160408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MaxPalletINPND
                  GOTO STEP_FAIL
               END
            END
            ELSE
            BEGIN
               IF EXISTS(SELECT 1
                  FROM LOC L (NOLOCK) 
                  WHERE L.loc=@nPND_LOC2
                  group by Maxpallet
                  HAVING @nPalletCount+1>L.Maxpallet)
               BEGIN
                  SET @nErrNo = 160408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MaxPalletINPND
                  GOTO STEP_FAIL
               END
            END

            SET @nPND_LOC2=@clocloop
         END

         If @nCounter =2
         BEGIN
            IF @nPND_LOC1<>@nPND_LOC2
            BEGIN
               SET @nErrNo = 160404
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
               GOTO STEP_FAIL
            END
            IF (@nPND_LOC1=@clocloop)
            BEGIN
               IF EXISTS(SELECT 1
                  FROM LOC L (NOLOCK) 
                  WHERE L.loc=@nPND_LOC1
                  group by Maxpallet
                  HAVING @nPalletCount+3>L.Maxpallet)
               BEGIN
                  SET @nErrNo = 160408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MaxPalletINPND
                  GOTO STEP_FAIL
               END
            END
            ELSE
            BEGIN
               IF EXISTS(SELECT 1
                  FROM LOC L (NOLOCK) 
                  WHERE L.loc=@nPND_LOC3
                  group by Maxpallet
                  HAVING @nPalletCount+1>L.Maxpallet)
               BEGIN
                  SET @nErrNo = 160408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MaxPalletINPND
                  GOTO STEP_FAIL
               END
            END

            SET @nPND_LOC3=@clocloop
         END

         If @nCounter =3
         BEGIN
             IF @nPND_LOC3<>@clocloop
            BEGIN
               SET @nErrNo = 160403
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
               GOTO STEP_FAIL
            END


            IF (@nPND_LOC3=@nPND_LOC1)
            BEGIN
               IF EXISTS(SELECT 1
                  FROM LOC L (NOLOCK) 
                  WHERE L.loc=@nPND_LOC1
                  group by Maxpallet
                  HAVING @nPalletCount+4>L.Maxpallet)
               BEGIN
                  SET @nErrNo = 160408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MaxPalletINPND
                  GOTO STEP_FAIL
               END
            END
            ELSE
            BEGIN
               IF EXISTS(SELECT 1
                  FROM LOC L (NOLOCK) 
                  WHERE L.loc=@nPND_LOC3
                  group by Maxpallet
                  HAVING @nPalletCount+2>L.Maxpallet)
               BEGIN
                  SET @nErrNo = 160408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MaxPalletINPND
                  GOTO STEP_FAIL
               END
            END
         END

         SET @nCounter=@nCounter+1

         FETCH NEXT FROM PalletLoc 
         INTO @ctaskdetailkeyloop,@clocloop

      END

      close PalletLoc
      DEALLOCATE PalletLoc; 

      GOTO QUIT
   END
   GOTO QUIT
END  


STEP_FAIL:
   close PalletLoc
   DEALLOCATE PalletLoc; 
   GOTO QUIT
  
QUIT:  


GO