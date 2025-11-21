SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_596ExtInfo01                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_OrderInquiry                               */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2015-03-30  1.0  ChewKP   SOS#337052 Created                         */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_596ExtInfo01] (    
    @nMobile        INT, 
    @nFunc          INT, 
    @cLangCode      NVARCHAR( 3),  
    @nStep          INT, 
    @cStorerKey     NVARCHAR( 15), 
    @cOrderKey      NVARCHAR( 20), 
    @cOutField01    NVARCHAR(60)  OUTPUT,
    @cOutField02    NVARCHAR(60)  OUTPUT,
    @cOutField03    NVARCHAR(60)  OUTPUT,
    @cOutField04    NVARCHAR(60)  OUTPUT,
    @cOutField05    NVARCHAR(60)  OUTPUT,
    @cOutField06    NVARCHAR(60)  OUTPUT,
    @cOutField07    NVARCHAR(60)  OUTPUT,
    @cOutField08    NVARCHAR(60)  OUTPUT,
    @cOutField09    NVARCHAR(60)  OUTPUT,
    @cOutField10    NVARCHAR(60)  OUTPUT,
    @nErrNo         INT           OUTPUT,
    @cErrMsg        NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF             
   
   DECLARE @nCounter        INT
          ,@cPickZone       NVARCHAR(10)
          ,@nRowCount       INT
          ,@nAllocatedCount INT
          ,@nPickedCount    INT
          ,@cStatus         NVARCHAR(15)
          ,@cGotoPickZone   NVARCHAR(10)
          
            
   SET @nErrNo   = 0            
   SET @cErrMsg  = ''  
   SET @cOutField02 = ''  

   DECLARE @t596 TABLE
   (
   RowRef                INT IDENTITY( 1, 1), 
   OrderKey              NVARCHAR(10),
   PickZone              NVARCHAR(10),
   QtyAllocated          INT,
   QtyPicked             INT
   )
             
             
   IF @nFunc = 596          
   BEGIN     
      
         IF @nStep = 1  -- Get Input Information   
         BEGIN           
            SET @nCounter         = 1        
            SET @nRowCount        = 0 
            SET @nAllocatedCount  = 0
            SET @nPickedCount     = 0 
            
              
            SELECT @nRowCount = Count (PickDetailKey)
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey
            
            SELECT @nAllocatedCount = Count (PTLKey)
            FROM dbo.PTLTran WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey
            AND Status = '0'
            
            SELECT @nPickedCount = Count (PTLKey)
            FROM dbo.PTLTran WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey
            AND Status = '9'
            
            IF @nRowcount = @nAllocatedCount 
            BEGIN
               SET @cOutField01 = 'Status: Open'
            END
            ELSE IF @nRowcount = @nPickedCount 
            BEGIN
               SET @cOutField01 = 'Status: Complete'
            END
            ELSE 
            BEGIN
               SET @cOutField01 = 'Status: InProgress'
            END      
            

            
            
            

            -- List of PickZone and Progress
            DECLARE CursorPickZone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
            SELECT Loc.PickZone 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PD.Loc
            WHERE PD.OrderKey = @cOrderKey
            GROUP BY Loc.PickZone 
                          
            OPEN CursorPickZone                
          
            FETCH NEXT FROM CursorPickZone INTO @cPickZone
           
            WHILE @@FETCH_STATUS <> -1         
            BEGIN  
               
               SET @nRowCount        = 0 
               SET @nAllocatedCount  = 0
               SET @nPickedCount     = 0 
                 
               SELECT @nRowCount = Count (PD.PickDetailKey)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PD.Loc
               WHERE PD.OrderKey = @cOrderKey
               AND Loc.PickZone = @cPickZone
               
               SELECT @nAllocatedCount = Count (PTL.PTLKey)
               FROM dbo.PTLTRAN PTL WITH (NOLOCK) 
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc
               WHERE PTL.OrderKey = @cOrderKey
               AND PTL.Status = '0'
               AND Loc.PickZone = @cPickZone
               
               SELECT @nPickedCount = Count (PTL.PTLKey)
               FROM dbo.PTLTRAN PTL WITH (NOLOCK) 
               INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.Loc
               WHERE OrderKey = @cOrderKey
               AND PTL.Status = '9'
               AND Loc.PickZone = @cPickZone
               
               
               INSERT INTO @t596 ( OrderKey , PickZone, QtyAllocated, QtyPicked )
               VALUES (@cOrderKey, @cPickZone, @nAllocatedCount, @nPickedCount)
               
        

               SET @cOutField04 = 'PickZone  ' + ' ' + 'Status'
               
               IF @nRowcount = @nAllocatedCount 
               BEGIN
                  SET @cStatus = 'Open'
               END
               ELSE IF @nRowcount = @nPickedCount 
               BEGIN
                  SET @cStatus = 'Complete'
               END
               ELSE 
               BEGIN
                  SET @cStatus = 'InProgress'
               END     
               
               
               
               IF @nCounter = 1
               BEGIN
                  SET @cOutField05 = @cPickZone + ' ' + @cStatus
               END
               ELSE IF @nCounter = 2 
               BEGIN
                  SET @cOutField06 = @cPickZone + ' ' + @cStatus
               END
               ELSE IF @nCounter = 3
               BEGIN
                  SET @cOutField07 = @cPickZone + ' ' + @cStatus
               END
               ELSE IF @nCounter = 4 
               BEGIN
                  SET @cOutField08 = @cPickZone + ' ' + @cStatus
               END
               ELSE IF @nCounter = 5 
               BEGIN
                  SET @cOutField09 = @cPickZone + ' ' + @cStatus
               END
               
               
               SET @nCounter = @nCounter + 1
               
               IF @nCounter > 5 
               BEGIN
                  BREAK
               END
               
               FETCH NEXT FROM CursorPickZone INTO @cPickZone
               
            END  
            CLOSE CursorPickZone                
            DEALLOCATE CursorPickZone      



            SELECT @cGotoPickZone = MAX(PickZone) 
            FROM @t596 
            WHERE OrderKey = @cOrderKey
            AND QtyPicked = 0 
            
            IF ISNULL(RTRIM(@cGotoPickZone),'') <> ''
            BEGIN
               SET @cOutField02 = 'Go To : ' + @cGotoPickZone
            END     
            ELSE
            BEGIN
               SET @cOutField02 = 'Go To : ' + 'NoPickZone'
               
            END
         END      
                
   END          
          

            
       
END     

GO