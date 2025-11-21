SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_GetOrderPromoDetail                                */
/* Creation Date: 2017-06-19                                            */
/* Copyright: LFL                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Mobile Dashboard                                            */
/*                                                                      */
/* Input Parameters: NONE                                               */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:    Mobile App                                             */
/*                                                                      */
/* PVCS Version: 1                                                      */ 
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/
CREATE PROC [API].[isp_GetOrderPromoDetail] 
	 @c_UserName		NVARCHAR(60)=''
  , @c_RespFormat    VARCHAR(10)  ='JSON'
  , @b_debug         INT          =0 
  , @c_RespString    NVARCHAR(MAX)=''  OUTPUT  
  , @b_Success       INT          =1   OUTPUT  
  , @n_Err           INT          =0   OUTPUT  
  , @c_ErrMsg        NVARCHAR(250)=''  OUTPUT   
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_NULLS ON;
   SET ANSI_WARNINGS ON;
   SET ANSI_PADDING ON;
    
    INSERT INTO API.TransactionLog
    ( UserName, Module) VALUES    ( @c_UserName, 'isp_GetOrderPromoDetail')
    
    DECLARE @dt_LastExtracion DATETIME
    
    SELECT @dt_LastExtracion = MAX(DATETIME)  
    FROM   V_DtsItf_Orders_SUM_SnapShot WITH (NOLOCK)
	 -- SET @dt_LastExtracion = '2016-06-19 09:00:03.000'
 
   IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL 
      DROP TABLE #RESULT 
   
   CREATE TABLE #RESULT (
   	Storer NVARCHAR(60), 
   	TTL_Orders              INT NULL DEFAULT 0,
      TTL_Orders_Open         INT NULL DEFAULT 0, 
      TTL_Orders_ALLOC        INT NULL DEFAULT 0, 
      TTL_Orders_Pick_Packed  INT NULL DEFAULT 0,
      TTL_Orders_Shipped      INT NULL DEFAULT 0, 
      TTL_Orders_Cancelled    INT NULL DEFAULT 0 ) 

   IF @c_UserName = 'demo@lflogistics.com'
	BEGIN
	   DECLARE 
	      @nStoreCount  INT,   @nRandom		   INT, @nRandom1		INT
	    , @nRandom2	  INT,	@nRandom3	   INT, @nRandom4		INT
	    , @nRandom5	  INT,   @ct	         INT, @nct	      INT
		 , @dyStore VARCHAR(MAX), @nStorerkey INT
		 		
		SET @nct = 7
		SET @ct = 0
		SET @nStoreCount = 0
		SET @nStorerkey = 1000

		WHILE @ct <= @nct
				BEGIN
					SET @dyStore  = CONVERT(VARCHAR(4),@nStorerkey + 1) + ' Storer' + CONVERT(VARCHAR(2),@nStoreCount + 1)
					SET @nRandom1 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
					SET @nRandom2 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
					SET @nRandom3 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
					SET @nRandom4 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
					SET @nRandom5 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
					SET @nRandom = @nRandom1 + @nRandom2 + @nRandom3 + @nRandom4 + @nRandom5

				  INSERT INTO #RESULT
				  (
      				Storer,
      				TTL_Orders,
      				TTL_Orders_Open,
      				TTL_Orders_ALLOC,
      				TTL_Orders_Pick_Packed,
      				TTL_Orders_Shipped,
      				TTL_Orders_Cancelled
				  )
				  VALUES
				  (
      				@dyStore,
      				@nRandom,
      				@nRandom1,
      				@nRandom2,
      				@nRandom3,
      				@nRandom4,
      				@nRandom5
				  )   
      			SET @ct = @ct + 1
				SET @nStoreCount = @nStoreCount + 1
				SET @nStorerkey = @nStorerkey + 1
		   END

		GOTO RESULT_OUTPUT
	END -- IF @c_UserName = 'demo@lflogistics.com'
	    
   INSERT INTO #RESULT 
   SELECT CASE WHEN OSS.StorerKey = '18467' THEN OSS.StorerKey + '-' + OSS.Facility + ' ' + OSS.StoreName
               ELSE OSS.Storerkey + ' ' + OSS.StoreName 
          END AS Storer, 
         SUM(OSS.TTL_Orders), 
         SUM(OSS.TTL_Orders_Open), 
         SUM(OSS.TTL_Orders_Alloc), 
         SUM(OSS.TTL_Orders_Pick_Packed), 
         SUM(OSS.TTL_Orders_Shipped), 
         SUM(OSS.TTL_Orders_Cancelled) 
   FROM   V_DtsItf_Orders_SUM_SnapShot OSS WITH (NOLOCK) 				
   WHERE  [DATETIME]=@dt_LastExtracion    
   AND    TTL_Orders > 0                
	AND    EXISTS(SELECT 1 FROM  [API].[UserRestrictions] As US WITH (NOLOCK) 
				WHERE US.[UserName] = @c_UserName 
			AND   US.[Restrictions] = 'STORER' 
			AND  (US.[Value] = '(ALL)' OR OSS.StorerKey = US.VALUE))
   GROUP BY CASE WHEN OSS.StorerKey = '18467' THEN OSS.StorerKey + '-' + OSS.Facility + ' ' + OSS.StoreName
               ELSE OSS.Storerkey + ' ' + OSS.StoreName 
          END

   IF NOT EXISTS(SELECT 1 FROM #RESULT)
   BEGIN
      INSERT INTO #RESULT
      (
      	Storer,
      	TTL_Orders,
      	TTL_Orders_Open,
      	TTL_Orders_ALLOC,
      	TTL_Orders_Pick_Packed,
      	TTL_Orders_Shipped,
      	TTL_Orders_Cancelled
      )
      VALUES
      (
      	'No Record',
      	0,
      	0,
      	0,
      	0,
      	0,
      	0
      )   
      	
   END
      
   RESULT_OUTPUT:
                    
   SELECT @c_RespString = API.fnc_FlattenedJSON(
               (
                SELECT * FROM #RESULT AS r 
                ORDER BY 1                	
                FOR XML PATH, ROOT
               )
           )
END

GO