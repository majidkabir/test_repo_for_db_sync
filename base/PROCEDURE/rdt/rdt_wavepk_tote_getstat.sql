SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_WavePK_Tote_GetStat                             */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 30-07-2020 1.0  Chermaine   WMS14247 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_WavePK_Tote_GetStat] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10)  -- WaveKey/ToteID
   ,@nPage           INT
   ,@cInputNo        NVARCHAR( 20)  --WavePK#/ToteID
   ,@cOutValue01     NVARCHAR( 20)  OUTPUT
   ,@cOutValue02     NVARCHAR( 20)  OUTPUT
   ,@cOutValue03     NVARCHAR( 20)  OUTPUT
   ,@cOutValue04     NVARCHAR( 20)  OUTPUT
   ,@cOutValue05     NVARCHAR( 20)  OUTPUT
   ,@cOutValue06     NVARCHAR( 20)  OUTPUT
   ,@nBalance        INT            OUTPUT
   ,@nErrNo          INT            OUTPUT
   ,@cErrMsg         NVARCHAR(250)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @result TABLE (           
    RN               INT,    
    R1               NVARCHAR( 20),  
    R2               NVARCHAR( 20),  
    R3               NVARCHAR( 20)
   )  
   
   DECLARE @cAsgnDropID    NVARCHAR( 20)
   DECLARE @cToteLoc       NVARCHAR( 20)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cQty           NVARCHAR( 5)
   DECLARE @cAltSKU        NVARCHAR( 20)
   DECLARE @cRow           NVARCHAR( 1)
   DECLARE @nMaxRow        INT
   
   SET @cRow = '0'
   
   INSERT INTO traceInfo (TraceName,col1,col2)
   VALUES ('ccInq',@cType,@nPage)
   IF @cType = 'WavePK'
   BEGIN
   	INSERT INTO @result
   	SELECT ROW_NUMBER() OVER(ORDER BY dropID,B_fax2 ASC) AS rn,dropID,B_fax2,'' FROM (
         SELECT  distinct PD.dropID,O.B_fax2
         FROM Pickdetail PD WITH (NOLOCK)  
         JOIN ORDERS O WITH (NOLOCK) ON (O.orderkey = PD.OrderKey AND O.StorerKey = PD.Storerkey)
         WHERE PD.storerKey = @cStorerKey 
         AND PD.waveKey + PD.caseID = @cInputNo
      )AW
      
      IF @@ROWCOUNT > 0  
      BEGIN
      	
      	SELECT @nMaxRow = MAX(RN) FROM @result
      	
      	IF @nPage = 1
         BEGIN
         	SET @nBalance = @nMaxRow - 6
         	
      	   DECLARE curWavePK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
      	      SELECT R1,R2 FROM @result WHERE RN BETWEEN 1 AND 6
         END
      
         IF @nPage > 1
         BEGIN
         	SET @nBalance = @nMaxRow - (@nPage*6)
         	
      	   DECLARE curWavePK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
      	      SELECT R1,R2 FROM @result WHERE RN BETWEEN (@nPage*6)-5 AND (@nPage*6)
         END
      
         OPEN curWavePK;  
         FETCH NEXT FROM curWavePK INTO @cAsgnDropID,@cToteLoc
         WHILE @@FETCH_STATUS = 0  
         BEGIN
      	   SET @cRow = @cRow + 1
      	
      	   IF @cRow = 1
      	   BEGIN
      		   SET @cOutValue01 = @cAsgnDropID+'  '+@cToteLoc
      	   END
      	
      	   IF @cRow = 2
      	   BEGIN
      		   SET @cOutValue02 = @cAsgnDropID+'  '+@cToteLoc
      	   END
      	
      	   IF @cRow = 3
      	   BEGIN
      		   SET @cOutValue03 = @cAsgnDropID+'  '+@cToteLoc
      	   END
      	
      	   IF @cRow = 4
      	   BEGIN
      		   SET @cOutValue04 = @cAsgnDropID+'  '+@cToteLoc
      	   END
      	
      	   IF @cRow = 5
      	   BEGIN
      		   SET @cOutValue05 = @cAsgnDropID+'  '+@cToteLoc
      	   END
      	
      	   IF @cRow = 6
      	   BEGIN
      		   SET @cOutValue06 = @cAsgnDropID+'  '+@cToteLoc
      	   END
         FETCH NEXT FROM curWavePK INTO @cAsgnDropID,@cToteLoc  
         END  
         CLOSE curWavePK  
         DEALLOCATE curWavePK 
      END
   END
   
   IF @cType = 'ToteID'
   BEGIN
   	INSERT INTO @result
   	SELECT  ROW_NUMBER() OVER(ORDER BY PD.SKU ASC) AS rn,
      PD.SKU,SUM(PD.QTY) AS QTY,S.ALTSKU
      FROM Pickdetail PD (NOLOCK)  
      JOIN SKU S (NOLOCK) ON (S.SKU = PD.SKU AND S.StorerKey = PD.Storerkey)
      JOIN ORDERS O (NOLOCK) ON (o.orderkey = PD.OrderKey AND o.StorerKey = PD.Storerkey)
      WHERE PD.storerKey = @cStorerKey
      AND PD.dropID  = @cInputNo 
      AND PD.status <> '9' 
      AND O.SOStatus <> '5'
      GROUP BY PD.SKU,S.ALTSKU
      ORDER BY PD.SKU
      
      IF @@ROWCOUNT > 0  
      BEGIN
      	
      	SELECT @nMaxRow = MAX(RN) FROM @result
      	
      	IF @nPage = 1
         BEGIN
         	SET @nBalance = @nMaxRow - 3
         	
      	   DECLARE curTote CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
      	      SELECT R1,R2,R3 FROM @result WHERE RN BETWEEN 1 AND 3
         END
      
         IF @nPage > 1
         BEGIN
         	SET @nBalance = @nMaxRow - (@nPage*3)
         	
      	   DECLARE curTote CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
      	      SELECT R1,R2,R3 FROM @result WHERE RN BETWEEN (@nPage*3)-2 AND (@nPage*3)
         END
      
         OPEN curTote;  
         FETCH NEXT FROM curTote INTO @cSKU,@cQty,@cAltSKU
         WHILE @@FETCH_STATUS = 0  
         BEGIN
      	   SET @cRow = @cRow + 1
      	
      	   IF @cRow = 1
      	   BEGIN
      		   SET @cOutValue01 = @cSKU+'  '+@cQty
      		   SET @cOutValue02 = @cAltSKU
      	   END
      	
      	   IF @cRow = 2
      	   BEGIN
      		   SET @cOutValue03 = @cSKU+'  '+@cQty
      		   SET @cOutValue04 = @cAltSKU
      	   END
      	
      	   IF @cRow = 3
      	   BEGIN
      		   SET @cOutValue05 = @cSKU+'  '+@cQty
      		   SET @cOutValue06 = @cAltSKU
      	   END
         FETCH NEXT FROM curTote INTO @cSKU,@cQty,@cAltSKU  
         END  
         CLOSE curTote  
         DEALLOCATE curTote 
      END
   END


Quit:

END

GO