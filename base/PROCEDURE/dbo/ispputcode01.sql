SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutCode01                                        */
/* Copyright: LF Logistic                                               */
/* Purpose: Pallet Putaway                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-02-27   ChewKP    1.0   WMS-1180 Created.                       */
/* 2017-07-26   ChewKP    1.1   WMS-2514 Load Balance Changes (ChewKP01)*/
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutCode01]
    @n_PTraceHeadKey             NVARCHAR(10)
   ,@n_PTraceDetailKey           NVARCHAR(10)
   ,@c_PutawayStrategyKey        NVARCHAR(10)
   ,@c_PutawayStrategyLineNumber NVARCHAR(5)
   ,@c_StorerKey NVARCHAR(15)
   ,@c_SKU       NVARCHAR(20)
   ,@c_LOT       NVARCHAR(10)
   ,@c_FromLoc   NVARCHAR(10)
   ,@c_ID        NVARCHAR(18)
   ,@n_Qty       INT     
   ,@c_ToLoc     NVARCHAR(10)
   ,@c_Param1    NVARCHAR(20)
   ,@c_Param2    NVARCHAR(20)
   ,@c_Param3    NVARCHAR(20)
   ,@c_Param4    NVARCHAR(20)
   ,@c_Param5    NVARCHAR(20)
   ,@b_debug     INT
   ,@c_SQL       NVARCHAR( 1000) OUTPUT
   ,@b_RestrictionsPassed INT   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Reason NVARCHAR(80)
   DECLARE @cLOC     NVARCHAR(10)
   DECLARE @cZone    NVARCHAR(10)
         , @c_PalletSKU NVARCHAR(20) 
         , @n_PalletQty INT
         , @c_PackKey   NVARCHAR(10) 
         , @n_PackPallet INT
         , @c_LocationCategory NVARCHAR(10) 
         , @c_PutawayZone NVARCHAR(10) 
         , @cpa_PutAwayZone01 NVARCHAR(10)
         , @cpa_PutAwayZone02 NVARCHAR(10)  
         , @cpa_PutAwayZone03 NVARCHAR(10)  
         , @cpa_PutAwayZone04 NVARCHAR(10)  
         , @cpa_PutAwayZone05 NVARCHAR(10) 
         , @nPutawayZoneCount  INT
         , @nLocAvailable      INT
         , @c_MultiPutawayZone NVARCHAR(100)   
         , @c_Facility        NVARCHAR(5) 
         , @c_TaskPutawayZone NVARCHAR(10) 
         , @cFirstPAZone      NVARCHAR(10) 
         , @cLastPAZone       NVARCHAR(10) 
         , @c_SearchZone      NVARCHAR(10) 
         , @cAvailablePutawayZone NVARCHAR(10) 
         , @cTestLoc NVARCHAR(10) 
         


   SET @cLOC = ''
   SET @cZone = ''
   
   -- Get Zone
   SELECT @cZone = PutawayZone01 
   FROM PutawayStrategyDetail WITH (NOLOCK) 
   WHERE PutawayStrategyKey = @c_PutawayStrategyKey
      AND PutawayStrategyLineNumber = @c_PutawayStrategyLineNumber
   
   SELECT    @c_PalletSKU = SKU
           , @n_PalletQty = SUM(Qty) 
   FROM dbo.LotxLocxID WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey
   AND ID = @c_ID
   AND Loc = @c_FromLoc
   GROUP BY SKU
   
   SELECT @c_PackKey = PacKKey 
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey
   AND SKU = @c_PalletSKU
   
   SELECT @n_PackPallet = Pallet 
   FROM dbo.Pack WITH (NOLOCK) 
   WHERE PackKey = @c_PackKey
   
   SELECT @c_LocationCategory = LocationCategory
         ,@c_PutawayZone = PutawayZone -- (ChewKP01) 
         ,@c_Facility    = Facility    -- (ChewKP01) 
   FROM dbo.Loc WITH (NOLOCK) 
   WHERE Loc = @c_ToLoc

   --SET @n_PalletQty = 120
   --SELECT @n_PalletQty '@n_PalletQty' , @n_PackPallet '@n_PackPallet' 

   IF @c_LocationCategory = 'OTHER' AND @n_PalletQty = @n_PackPallet
   BEGIN
   
      SELECT TOP 1 @c_TaskPutawayZone = ISNULL(Loc.PutawayZone,'') 
      FROM dbo.TaskDetail TD WITH (NOLOCK)  
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = TD.ToLoc
      WHERE TD.StorerKey = @c_StorerKey
      AND TD.TaskType    = 'PAF'
      --AND TD.FromID      = @c_ID
      AND TD.Status      = '9'
      AND TD.SourceType  = 'rdt_1819ExtUpd05'
      ORDER BY TD.TaskDetailKey DESC

      IF @c_TaskPutawayZone = '' 
      BEGIN
         SET @c_TaskPutawayZone = @cFirstPAZone 
      END

   
      SELECT TOP 1 @cFirstPAZone = PutawayZone
      FROM dbo.Loc WITH (NOLOCK) 
      WHERE Facility = @c_Facility 
      AND LocationCategory = 'OTHER'
      ORDER BY PutawayZone
   
      SELECT TOP 1 @cLastPAZone = PutawayZone
      FROM dbo.Loc WITH (NOLOCK) 
      WHERE Facility = @c_Facility
      AND LocationCategory = 'OTHER'
      ORDER BY PutawayZone DESC
   
      --SELECT @c_PutawayStrategyKey '@c_PutawayStrategyKey' , @c_PutawayZone '@c_PutawayZone', @c_TaskPutawayZone '@c_TaskPutawayZone',  @cFirstPAZone '@cFirstPAZone' , @cLastPAZone '@cLastPAZone' 
   
      SELECT   
            @c_SearchZone          = Zone,  
            @cpa_PutAwayZone01     = PutAwayZone01,  
            @cpa_PutAwayZone02     = PutAwayZone02,  
            @cpa_PutAwayZone03     = PutAwayZone03,  
            @cpa_PutAwayZone04     = PutAwayZone04,  
            @cpa_PutAwayZone05     = PutAwayZone05  
      FROM  PUTAWAYSTRATEGYDETAIL WITH (NOLOCK)  
      WHERE PutAwayStrategyKey = @c_PutawayStrategyKey --AND  
            --putawaystrategylinenumber>@c_PutawayStrategyLineNumber  
      --ORDER BY putawaystrategylinenumber  

     
       
      SET @nPutawayZoneCount = 0   
      SET @c_MultiPutawayZone = '' 
   
      DECLARE @tPutwayZoneList TABLE (PutawayZone NVARCHAR(10)) 

  
      IF ISNULL(RTRIM(@cpa_PutAwayZone01),'' )  <> ''   
      BEGIN  
         INSERT into @tPutwayZoneList  (PutawayZone) VALUES (@cpa_PutAwayZone01)
      END  

      IF ISNULL(RTRIM(@cpa_PutAwayZone02),'' )  <> ''   
      BEGIN  
         INSERT into @tPutwayZoneList  (PutawayZone) VALUES  (@cpa_PutAwayZone02)
      END  

      IF ISNULL(RTRIM(@cpa_PutAwayZone03),'' )  <> ''   
      BEGIN  
         INSERT into @tPutwayZoneList  (PutawayZone) VALUES (@cpa_PutAwayZone03)
      END  

      IF ISNULL(RTRIM(@cpa_PutAwayZone04),'' )  <> ''   
      BEGIN  
         INSERT into @tPutwayZoneList  (PutawayZone) VALUES (@cpa_PutAwayZone04)
      END  

      IF ISNULL(RTRIM(@cpa_PutAwayZone05),'' )  <> ''   
      BEGIN  
         INSERT into @tPutwayZoneList  (PutawayZone) VALUES (@cpa_PutAwayZone05)
      END  

      IF ISNULL(@c_SearchZone,'')  <> '' 
      BEGIN
         INSERT into @tPutwayZoneList  (PutawayZone) VALUES (@c_SearchZone)
      END
   
   

      IF EXISTS ( 
                  SELECT 1
                  FROM LOC WITH (NOLOCK) 
                  LEFT OUTER JOIN LotxLocxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Loc = Loc.Loc) 
                  WHERE LOC.putawayzone IN (  SELECT PutawayZone FROM @tPutwayZoneList )
                  AND LOC.PutawayZone > @c_TaskPutawayZone --@c_PutawayZone
                  AND   LOC.Facility =  RTRIM( @c_Facility) 
                  AND LocationCategory = 'OTHER'
                  GROUP BY LOC.PALogicalLoc, LOC.LOC 
                  HAVING SUM( ISNULL(LotxLocxID.Qty,0) - ISNULL(LotxLocxID.QtyPicked,0))= 0 
                  AND SUM(ISNULL(LotxLocxID.PendingMoveIn,0) ) = 0
                  AND SUM(ISNULL(LotxLocxID.QtyExpected,0)) = 0 )
                  
      BEGIN
            SET @nLocAvailable = 1 
      END
      ELSE 
      BEGIN
            SET @nLocAvailable = 0 
      END
   
   
      --SELECT @nLocAvailable, '@nLocAvailable' , @c_TaskPutawayZone '@c_TaskPutawayZone', @cLastPAZone '@cLastPAZone' , @cFirstPAZone '@cFirstPAZone' , @c_PutawayZone '@c_PutawayZone' 
      
      IF @nLocAvailable = 1    
      BEGIN
         -- (ChewKP01) 
         IF @c_TaskPutawayZone = @cLastPAZone
         BEGIN 
         
            IF @c_PutawayZone <> @cFirstPAZone 
            BEGIN 
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FAILED PutCode: ispPutCode01  PutawayZone Not In Sequence 1.'
                  EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
               END
               SET @b_RestrictionsPassed = 0 --False
               GOTO QUIT
            END
         END
         ELSE
         BEGIN
            
            IF @c_PutawayZone <= @c_TaskPutawayZone 
            BEGIN 
               IF @b_debug = 1
               BEGIN
                  SELECT @c_Reason = 'FAILED PutCode: ispPutCode01  PutawayZone Not In Sequence 2.'
                  EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
               END
               SET @b_RestrictionsPassed = 0 --False
               GOTO QUIT
            END
         END
      END
      ELSE IF @nLocAvailable = 0
      BEGIN
         IF EXISTS ( 
                  SELECT 1
                  FROM LOC WITH (NOLOCK) 
                  LEFT OUTER JOIN LotxLocxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Loc = Loc.Loc) 
                  WHERE LOC.putawayzone IN (  SELECT PutawayZone FROM @tPutwayZoneList )
                  AND LOC.PutawayZone < @c_TaskPutawayZone --@c_PutawayZone
                  AND   LOC.Facility =  RTRIM( @c_Facility) 
                  AND LocationCategory = 'OTHER'
                  GROUP BY LOC.PALogicalLoc, LOC.LOC 
                  HAVING SUM( ISNULL(LotxLocxID.Qty,0) - ISNULL(LotxLocxID.QtyPicked,0))= 0 
                  AND SUM(ISNULL(LotxLocxID.PendingMoveIn,0) ) = 0
                  AND SUM(ISNULL(LotxLocxID.QtyExpected,0)) = 0 )
         BEGIN
                  SELECT TOP 1 @cAvailablePutawayZone = Loc.PutawayZone
                  FROM LOC WITH (NOLOCK) 
                  LEFT OUTER JOIN LotxLocxID WITH (NOLOCK, INDEX=IDX_LOTxLOCxID_LOC) ON (LotxLocxID.Loc = Loc.Loc) 
                  WHERE LOC.putawayzone IN (  SELECT PutawayZone FROM @tPutwayZoneList )
                  AND LOC.PutawayZone < @c_TaskPutawayZone --@c_PutawayZone
                  AND   LOC.Facility =  RTRIM( @c_Facility) 
                  AND LocationCategory = 'OTHER'
                  GROUP BY LOC.PALogicalLoc, LOC.LOC, LOC.PutawayZone
                  HAVING SUM( ISNULL(LotxLocxID.Qty,0) - ISNULL(LotxLocxID.QtyPicked,0))= 0 
                  AND SUM(ISNULL(LotxLocxID.PendingMoveIn,0) ) = 0
                  AND SUM(ISNULL(LotxLocxID.QtyExpected,0)) = 0 
                  ORDER BY LOC.PutawayZone

            
            --SELECT @cTestLoc '@cTestLoc' ,  @c_Facility '@c_Facility', @c_TaskPutawayZone '@c_TaskPutawayZone' , @c_PutawayZone '@c_PutawayZone' , @cAvailablePutawayZone '@cAvailablePutawayZone'  ,@cFirstPAZone '@cFirstPAZone' 
              
            -- (ChewKP01) 
            IF @c_PutawayZone <> @cAvailablePutawayZone
            BEGIN 
            
               --IF @c_PutawayZone <> @cFirstPAZone 
               --BEGIN 
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_Reason = 'FAILED PutCode: ispPutCode01  PutawayZone Not In Sequence 3.'
                     EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
                  END
                  SET @b_RestrictionsPassed = 0 --False
                  GOTO QUIT
               --END
            END
           
         END
      END
   END
   --INSERT INTO TRaceInfo (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5 ) 
   --VALUES ( 'ispPutCode01' , Getdate() , @cZone, @c_PalletSKU, @c_PackKey, @n_PackPallet , @c_LocationCategory, @c_ToLoc, @c_PutawayStrategyKey ,@c_PutawayStrategyLineNumber,@n_PalletQty  ,'' ) 

   --SELECT @n_PalletQty '@n_PalletQty' ,   @n_PackPallet '@n_PackPallet' , @c_FromLoc '@c_FromLoc' 
    
   IF (@n_PalletQty = @n_PackPallet AND @c_LocationCategory <> 'OTHER')
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED PutCode: ispPutCode01  Location Category is not BULK'
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
      END
      SET @b_RestrictionsPassed = 0 --False
   END
   ELSE IF  (@n_PalletQty < @n_PackPallet AND @c_LocationCategory <> 'SHELVING')
   BEGIN
   		 IF @c_PutawayStrategyLineNumber <> '00003'
   		 BEGIN
   		    IF @b_debug = 1
             BEGIN
   	          SELECT @c_Reason = 'FAILED PutCode: ispPutCode01  Location Category is not SHELVING'
   	          EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
	          END
	          SET @b_RestrictionsPassed = 0 --False
     	    END	
     	 
   END
   ELSE IF (@n_PalletQty > @n_PackPallet )
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED PutCode: ispPutCode01  PalletQty > Pack.Pallet'
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
      END
      SET @b_RestrictionsPassed = 0 --False
   END

QUIT:
--SELECT  @c_ToLoc '@c_ToLoc', @b_RestrictionsPassed '@b_RestrictionsPassed'  -- TESTING
END

GO