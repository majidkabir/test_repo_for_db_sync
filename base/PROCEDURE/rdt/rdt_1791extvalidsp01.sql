SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1791ExtValidSP01                                */  
/* Purpose: Validate Pallet DropID                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2014-02-10 1.2  ChewKP     SOS#293509 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1791ExtValidSP01] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cFacility   NVARCHAR(5),
   @cDropID     NVARCHAR(20),  
   @cSuggestedLOC NVARCHAR(10) OUTPUT,
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 1791  
BEGIN  
   
    DECLARE @cDDropID NVARCHAR(20)
           ,@cDropLoc NVARCHAR(10)
           
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    SET @cDDropID        = ''
    SET @cSuggestedLOC   = ''
    SET @cDropLoc        = ''
    
    -- Get Any Empty Location which not in DropID.DropLoc
    SELECT TOP 1 @cSuggestedLOC = Loc.Loc 
    FROM dbo.Loc Loc WITH (NOLOCK) 
    WHERE Loc.Loc Not IN ( SELECT DropLoc FROM dbo.DropID WITH (NOLOCK)
                           WHERE DropIDType = 'B' 
                           AND Status = '9' ) 
    AND Loc.LocationCategory = 'PACK&HOLD'
    AND Loc.Facility         = @cFacility
    ORDER BY LOC.LogicalLocation       
    
 
    
    IF @cSuggestedLoc = ''         
    BEGIN


       -- Find Empty Location From DropID
       DECLARE CUR_DropLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       
       SELECT DISTINCT DropID.DropID, DropID.DropLoc 
       FROM dbo.DropID DropID WITH (NOLOCK)
       INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON DD.DropID = DropID.DropID
       INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DropID.DropLoc
       WHERE DropID.DropIDType = 'B'
       AND DD.UserDefine01 <> ''
       AND DropID.Status = '9'
       AND Loc.LocationCategory = 'PACK&HOLD'
       ORDER BY DropID.DropLoc
       
       OPEN CUR_DropLoc
       FETCH NEXT FROM CUR_DropLoc INTO @cDDropID, @cDropLoc
       WHILE (@@FETCH_STATUS <> -1)
       BEGIN
         
         IF NOT EXISTS ( SELECT 1 FROM DROPIDDETAIL DD WITH (NOLOCK)
                         INNER JOIN DROPID D WITH (NOLOCK) ON D.DROPID = DD.DROPID
                         WHERE D.DROPLOC = @cDropLoc
                         AND ISNULL(USERDEFINE01,'')  = '' ) 
         BEGIN
            SET @cSuggestedLOC = @cDropLoc
            BREAK
         END         
                      
         FETCH NEXT FROM CUR_DropLoc INTO @cDDropID, @cDropLoc
         
       END                       
       CLOSE CUR_DropLoc         
       DEALLOCATE CUR_DropLoc    
    END

END  
  
 
QUIT:  

 

GO