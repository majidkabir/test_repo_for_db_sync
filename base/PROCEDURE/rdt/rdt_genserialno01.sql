SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/  
/* Store procedure: rdt_GenSerialNo01                                   */  
/* Purpose: LOGITECH                                                    */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-05-26 1.0  ChewKP     WMS-1931 Created                          */   
/* 2022-07-28 1.1  Calvin     JSM-85080 Corrected WeekCode (CLVN01)     */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_GenSerialNo01] (  
   @nMobile                   INT,             
   @nFunc                     INT,             
   @cLangCode                 NVARCHAR( 3),    
   @nStep                     INT,             
   @nInputKey                 INT,             
   @cStorerkey                NVARCHAR( 15),   
   @cFromSKU                  NVARCHAR( 20),   
   @cToSKU                    NVARCHAR( 20),   
   @cSerialNo                 NVARCHAR( 20),   
   @cSerialType               NVARCHAR( 10),  
   @cWorkOrderKey             NVARCHAR( 10),  
   @cBatchKey                 NVARCHAR( 10),   
   @cNewSerialNo              NVARCHAR( 20) OUTPUT,   
   @nErrNo                    INT           OUTPUT,    
   @cErrMsg                   NVARCHAR( 20) OUTPUT     
)  
AS  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @nTranCount     INT,  
           @bSuccess       INT,   
           @cFacility      NVARCHAR( 5),  
           @cOrderKey      NVARCHAR( 10),   
           @cStatus    NVARCHAR(10),  
           @nRowRef   INT,  
           @cFromSerialNo  NVARCHAR(20),   
           @cYearCode      NVARCHAR(2),  
           @cWeekCode      NVARCHAR(2),  
           @cMfgCode       NVARCHAR(2),  
           @cSeqNo         NVARCHAR(5),  
           @cUserName      NVARCHAR(18),  
           --@cWorkOrderKey   NVARCHAR(10),  
           @cMfgDate       NVARCHAR(10),  
           @dMfgDate       DATE,  
           @cLogiSerial    NVARCHAR(5),  
           @cCharPart       NVARCHAR(2)  
             
   SELECT @cFacility = Facility  
         ,@cUserName = UserName   
   FROM RDT.RDTMOBREC WITH (NOLOCK)   
   WHERE Mobile = @nMobile  
  
     
     
   SET @nErrNo = 0   
   SET @cErrMsg = ''  
     
   SET @cFromSerialNo  = ''  
   SET @cYearCode      = ''  
   SET @cWeekCode      = ''  
   SET @cMfgCode       = ''  
   SET @cSeqNo         = ''  
     
   --GetKey   
   EXECUTE dbo.nspg_GetKey  
   'LOGISERIAL',  
   3  ,  
   @cSeqNo            OUTPUT,  
   @bSuccess          OUTPUT,  
   @nErrNo            OUTPUT,  
   @cErrMsg           OUTPUT  
     
   SELECT @cCharPart = AlphaCount   
   FROM dbo.Ncounter WITH (NOLOCK)   
   WHERE KeyName = 'LOGISERIAL'  
  
     
  
   IF ISNULL(@cSeqNo , ''  ) = '001' --RIGHT(@cSeqNo , 1 ) = '1'  
   BEGIN  
         
       IF SUBSTRING(@cCharPart,2,1)<>'Z' -- 2nd Alphabet <> 'Z' increase the Alphabet roll  
       BEGIN  
              IF CHAR(ASCII(SUBSTRING(@cCharPart,2,1))+1) IN ( 'I' , 'O' )   
              BEGIN   
               SET @cCharPart = LEFT(@cCharPart,1)+CHAR(ASCII(SUBSTRING(@cCharPart,2,1))+2)  
              END  
              ELSE  
              BEGIN  
               SET @cCharPart = LEFT(@cCharPart,1)+CHAR(ASCII(SUBSTRING(@cCharPart,2,1))+1)  
              END  
  
              --SET @nSeqNo = 1  
              --INSERT INTO @test  
              --SELECT @cCharPart+RIGHT(('000'+CAST(@nSeqNo AS varchar(3))),3)  
              SET @cLogiSerial = @cCharPart + @cSeqNo  
       END  
       ELSE IF SUBSTRING(@cCharPart,2,1)='Z' AND SUBSTRING(@cCharPart,1,1) <>'Z' --2nd Alphabet = 'Z' increase the Alphabet roll of First Character  
       BEGIN  
              IF CHAR(ASCII(SUBSTRING(@cCharPart,1,1))+1) IN ( 'I' , 'O' )   
              BEGIN  
               SET @cCharPart = CHAR(ASCII(SUBSTRING(@cCharPart,1,1))+2)+'A'  
              END  
              ELSE  
              BEGIN  
               SET @cCharPart = CHAR(ASCII(SUBSTRING(@cCharPart,1,1))+1)+'A'  
              END  
  
              --SET @nSeqNo = 1  
              --INSERT INTO @test  
              --SELECT @cCharPart+RIGHT(('000'+CAST(@nSeqNo AS varchar(3))),3)  
              SET @cLogiSerial = @cCharPart + @cSeqNo  
       END   
       ELSE IF SUBSTRING(@cCharPart,1,1)='Z'   
       BEGIN  
                
              SET @cCharPart = 'AA'  
              --SET @nSeqNo = 1  
              --INSERT INTO @test  
              --SELECT @cCharPart+RIGHT(('000'+CAST(@nSeqNo AS varchar(3))),3)  
              SET @cLogiSerial = @cCharPart + @cSeqNo  
              --BREAK  
       END   
       --BREAK  
   END  
   ELSE  
   BEGIN  
      
       --SET @nSeqNo=@nSeqNo+1  
  
       --INSERT INTO @test  
       --SELECT @cCharPart+RIGHT(('000'+CAST(@nSeqNo AS varchar(3))),3)  
       SET @cLogiSerial = @cCharPart + @cSeqNo  
  
   END  
     
   UPDATE dbo.Ncounter WITH (ROWLOCK)   
   SET AlphaCount = @cCharPart   
   WHERE KeyName = 'LOGISERIAL'  
  
   IF @nFunc = 1008  
   BEGIN   
      IF @nInputKey = 1  
      BEGIN  
         IF @nStep = 2  
         BEGIN  
              
            IF @cSerialType = 'EACHES'  
            BEGIN  
                       
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + '9'  
                    
  
                 
            END  
            ELSE IF @cSerialType = 'INNER'  
            BEGIN  
                 
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'C'  
                    
                
                 
            END  
            ELSE IF @cSerialType = 'MASTER'  
            BEGIN  
                 
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  --                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'M'  
                    
               
                 
            END  
         END     
      END  
   END  
     
   IF @nFunc = 1010  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF @nStep = 2  
         BEGIN  
              
            IF @cSerialType = 'EACHES'  
            BEGIN  
                 
                  
               IF ISNULL(@cWorkOrderKey,'')  <> ''  
               BEGIN   
                  SELECT @cMfgDate = WkOrdUdef2  
                  FROM dbo.WorkOrder WITH (NOLOCK)   
                  WHERE WorkOrderKey = @cWorkOrderKey   
  
                  IF ISDATE(@cMfgDate) = 1   
                  BEGIN  
                     SET @dMfgDate = @cMfgDate  
                  END  
                  ELSE  
                  BEGIN  
                     -- Invalid Date Format  
                     SET @nErrNo = -1   
                     --SET @dMfgDate = GetDate()   
                       
                  END  
                    
                  SET @cYearCode = RIGHT(YEAR(@dMfgDate) , 2 )   
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, @dMfgDate ) - 1 AS VARCHAR(2)),2)  --(CLVN01)
                    
  
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                   
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + '9'  
  
                    
               END  
               ELSE   
               BEGIN  
                  SET @nErrNo = -1   
               END  
                 
                 
            END  
            ELSE IF @cSerialType = 'INNER'  
            BEGIN  
                 
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'C'  
  
                         
                 
            END  
            ELSE IF @cSerialType = 'MASTER'  
            BEGIN  
                 
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())                  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                   --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'M'  
                    
                 
                 
            END  
         END     
      END  
   END  
     
   IF @nFunc = 1011  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF @nStep = 2  
         BEGIN  
              
            IF @cSerialType = 'EACHES'  
            BEGIN  
                 
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + '9'  
                    
                 
                 
                 
            END  
            ELSE IF @cSerialType = 'INNER'  
            BEGIN  
                 
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) -1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'C'  
                
                 
                 
            END  
            ELSE IF @cSerialType = 'MASTER'  
            BEGIN  
                 
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'M'  
              
                 
                 
            END  
         END     
      END  
   END  
     
   IF @nFunc = 1012  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN           IF @nStep = 2  
         BEGIN  
              
            IF @cSerialType = 'EACHES'  
            BEGIN  
                
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + '9'  
                  
                 
                 
            END  
            ELSE IF @cSerialType = 'INNER'  
            BEGIN  
                 
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'C'  
                    
               
                 
                 
            END  
            ELSE IF @cSerialType = 'MASTER'  
            BEGIN  
                
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'M'  
                    
            
                 
                 
            END  
         END     
      END  
   END  
       
   IF @nFunc = 1013  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF @nStep = 2  
         BEGIN  
              
            IF @cSerialType = 'EACHES'  
            BEGIN  
                
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + '9'  
                  
                 
                 
            END  
            ELSE IF @cSerialType = 'INNER'  
            BEGIN  
                 
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'C'  
                    
               
                 
                 
            END  
            ELSE IF @cSerialType = 'MASTER'  
            BEGIN  
                
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                  --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'M'  
                    
            
                 
                 
            END  
         END     
      END  
   END  
  
     
     
   IF @nFunc = 593  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF @nStep = 2  
         BEGIN  
              
            IF @cSerialType = 'EACHES'  
            BEGIN  
                
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                --GetKey   
--                  EXECUTE dbo.nspg_GetKey  
--                  'LOGISERIAL',  
--                  5  ,  
--                  @cSeqNo            OUTPUT,  
--                  @bSuccess          OUTPUT,  
--                  @nErrNo            OUTPUT,  
--                  @cErrMsg           OUTPUT  
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + '9'  
                  
                 
                 
            END  
            ELSE IF @cSerialType = 'INNER'  
            BEGIN  
                    
  
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'C'  
                    
               
                 
                 
            END  
            ELSE IF @cSerialType = 'MASTER'  
            BEGIN  
                
                  SET @cYearCode = SUBSTRING( CAST(Year(GetDate()) AS NVARCHAR(4) ), 3, 2 )   
                  --SET @cWeekCode = DATEPART( wk, GetDate())  
                  SET @cWeekCode = RIGHT('00'+CAST(DATEPART(Week, GetDate() ) - 1 AS VARCHAR(2)),2) --JyhBin  --(CLVN01)
                  --SET @cMfgCode  = SUBSTRING ( @cFromSerialNo, 5 , 2 )  
                    
                  SELECT @cMfgCode = Short   
                  FROM dbo.CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'LOGILOC'  
                  AND Code = @cFacility   
                    
                    
                  SET @cNewSerialNo = @cYearCode + @cWeekCode + @cMfgCode + @cLogiSerial + 'M'  
  
            END  
         END     
      END  
   END  
   GOTO Quit  
     
     
   RollBackTran:    
         ROLLBACK TRAN rdt_GenSerialNo01    
   Quit:    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    

GO