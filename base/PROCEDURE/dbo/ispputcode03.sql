SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutCode03                                        */
/* Copyright: LF Logistic                                               */
/* Purpose: SKU Putaway                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-03-23   ChewKP    1.0   WMS-3836 Created.                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutCode03]
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
          ,@cDPPLoc  NVARCHAR(10) 
          ,@cReceiptKey NVARCHAR(10) 
          ,@cFacility   NVARCHAR(5) 
          ,@cDate       NVARCHAR(10) 
          ,@cTime       NVARCHAR(13)
          ,@dDatePlus1  DATETIME
          ,@nDay        INT
          ,@nMonth      INT
          ,@nYear       INT
          ,@dCurrentDate DATETIME
          ,@dNewDate     DATETIME
          
   --SELECT LEFT( CONVERT(VARCHAR(11),GETDATE(),121) , 10 ) 
   SET @cDate = LEFT( CONVERT(VARCHAR(11),GETDATE(),121) , 10 ) 
   SET @dDatePlus1 = DATEADD (d ,1,  GETDATE() ) 
   SET @cTime = ' 09:00:00.000'
   
   SET @nDay   = Day (@dDatePlus1)
   SET @nMonth = Month (@dDatePlus1)
   SET @nYear  = Year (@dDatePlus1)
   
   SET @dCurrentDate = @cDate + @cTime
   
   SET @dNewDate = CONVERT(DATETIME, RIGHT('0000'+@nYear,4) + '-' + RIGHT('00'+@nMonth,2) + '-' + RIGHT('00'+@nDay,2) + @cTime , 121 ) 
   
   --SELECT @dCurrentDate '@dCurrentDate' , @dNewDate '@dNewDate'

   --GOTO QUIT 

   SELECT @cDPPLoc = Data
   FROM dbo.SKUConfig WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey
   AND SKU = @c_SKU
   AND ConfigType = 'DefaultDPP'
   
   -- GET ASN Number
   SELECT TOP 1 
             @cReceiptKey = V_ReceiptKey
            ,@cFacility   = Facility
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey 
   AND Func = '607'
   AND Step IN (3 ,4 )
   
   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               --WHERE ReceiptKey = @cReceiptKey
               INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
               AND RD.StorerKey = @c_StorerKey
               AND R.Facility = @cFacility
               AND RD.ToLoc = @c_ToLoc
               --AND R.RecType = 'NORMAL' 9 - 9
               --AND CONVERT(VARCHAR(11),RD.EditDate,103) =CONVERT(VARCHAR(11),GETDATE(),103) 
               AND RD.EditDate BETWEEN @dCurrentDate AND @dNewDate)
   BEGIN
       IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'FAILED PutCode: ispPutCode03  ToLoc Exists in ReceiptDetail'
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
      END
      SET @b_RestrictionsPassed = 0 --False
      
   END               

   
--   IF ISNULL(@cDPPLoc,'')  = ''  
--   BEGIN
--      IF @b_debug = 1
--      BEGIN
--         SELECT @c_Reason = 'FAILED PutCode: ispPutCode03  SKUConfig Not Setup'
--         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
--      END
--      SET @b_RestrictionsPassed = 0 --False
--   END
   
   

QUIT:
--SELECT  @c_ToLoc '@c_ToLoc', @b_RestrictionsPassed '@b_RestrictionsPassed'  -- TESTING
END

GO