SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_GetOrderPromoSumm                                  */
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
CREATE PROC [API].[isp_GetOrderPromoSumm] 
	 @c_UserName      NVARCHAR(60)  ='' 
  , @c_RespFormat    VARCHAR(10)   = 'JSON'
  , @b_debug         INT           = 0 
  , @c_RespString    NVARCHAR(MAX) = ''  OUTPUT  
  , @b_Success       INT           = 1   OUTPUT  
  , @n_Err           INT           = 0   OUTPUT  
  , @c_ErrMsg        NVARCHAR(250) = ''  OUTPUT   
AS
BEGIN     
   SET NOCOUNT ON;
   SET ANSI_NULLS ON;
   SET ANSI_WARNINGS ON;
   SET ANSI_PADDING ON;
	
    INSERT INTO API.TransactionLog
    ( UserName, Module) VALUES    ( @c_UserName, 'isp_GetOrderPromoSumm')
    	
   DECLARE @cHour       VARCHAR(5), 
           @c_Next_Date VARCHAR(10),
           @n_Curr_Hour INT,
           @n_Next_Hour INT, 
           @n_Interval  INT, 
           @n_Count     INT, 
           @d_Last_Date DATETIME, 
           @d_Next_Date DATETIME, 
           @d_Start_Date DATETIME,
           @d_End_Date   DATETIME

   DECLARE
           @nTotalOrder INT, @nPrevTotalOrder INT, @nVarTotalOrder INT
         , @nTotalOpen  INT, @nPrevTotalOpen  INT, @nVarTotalOpen  INT
         , @nTotalAlloc INT, @nPrevTotalAlloc INT, @nVarTotalAlloc INT
         , @nTotalPick  INT, @nPrevTotalPick  INT, @nVarTotalPick  INT
         , @nTotalShip  INT, @nPrevTotalShip  INT, @nVarTotalShip  INT
         , @nTotalCanc  INT, @nPrevTotalCanc  INT, @nVarTotalCanc  INT
         , @nHour       INT
         , @nCounter    INT

   SELECT
           @nTotalOrder = 0, @nPrevTotalOrder = 0
         , @nTotalOpen  = 0, @nPrevTotalOpen  = 0
         , @nTotalAlloc = 0, @nPrevTotalAlloc = 0
         , @nTotalPick  = 0, @nPrevTotalPick  = 0
         , @nTotalShip  = 0, @nPrevTotalShip  = 0
         , @nTotalCanc  = 0, @nPrevTotalCanc  = 0
            
   IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL
      DROP TABLE #RESULT
   
   CREATE TABLE #RESULT (
	   RowNo       INT IDENTITY(1,1), 
	   CDate       VARCHAR(10), 
	   CTtl        INT, 
	   COpen       DECIMAL(10,1),
	   CAllocated  DECIMAL(10,1),
	   CPacked     DECIMAL(10,1),
	   CShipped    DECIMAL(10,1),
	   CCancelled  DECIMAL(10,1),	   
	   TOpen       DECIMAL(10,1),
	   TAllocated  DECIMAL(10,1),
	   TPacked     DECIMAL(10,1),
	   TShipped    DECIMAL(10,1),
	   TCancelled  DECIMAL(10,1),	   	   
	   Header      INT, 
	   AddHour     INT, 
	   SeqNo       INT )

   -- Dummy Record -- 
   DECLARE 
		   @nRandom		INT, @nRandom1		INT, @nRandom2		INT
		 , @nRandom3	INT, @nRandom4		INT, @nRandom5		INT
		 , @nRandom6	INT, @nRandom7		INT, @nRandom8		INT
		 , @nRandom9	INT, @nRandom10	INT, @ct	         INT
		 , @nct	      INT, @dtf         INT, @dtb  VARCHAR(2)
		 , @fDate VARCHAR(5)
		    
	SET @nct = 7
	SET @ct  = 0
	SET @dtf = 1
	SET @dtb = '00'
	IF @c_UserName = 'demo@lflogistics.com'
	BEGIN
		WHILE @ct <= @nct
		BEGIN
			SET @fDate = '0' + CONVERT(VARCHAR(2),@dtf + 1) + ':' + @dtb
			SET @nRandom1 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom2 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom3 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom4 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom5 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom6 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom7 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom8 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom9 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom10 = ROUND(((1000 - 10 - 1) * RAND() + 10), 0)
			SET @nRandom = @nRandom1 + @nRandom2 + @nRandom3 + @nRandom4 + @nRandom5 +
				@nRandom6 + @nRandom7 + @nRandom8 + @nRandom9 + @nRandom10

			INSERT INTO #RESULT
			   ( CDate,			CTtl,			COpen,		
				 CAllocated,	CPacked,		CShipped, 	
				 CCancelled,	TOpen,			TAllocated, 
				 TPacked,		TShipped,		TCancelled,  	
				 Header,		AddHour,		SeqNo)
			VALUES 
				(  @fDate,			@nRandom,		@nRandom1,
				   @nRandom2,		@nRandom3,		@nRandom4,	          
				   @nRandom5,		@nRandom6,		@nRandom7, 
				   @nRandom8,		@nRandom9,		@nRandom10, 
				   (0),				(0),			(0))
		   
				  SET @ct = @ct + 1
				  SET @dtf = @dtf + 1
		END
		BEGIN
		  INSERT INTO #RESULT
		  (  CDate,			CTtl,			COpen,		
			 CAllocated,	CPacked,		CShipped, 	
			 CCancelled,	TOpen,			TAllocated, 
			 TPacked,		TShipped,		TCancelled,	
			 Header,		AddHour,		SeqNo)
		  VALUES (
				'Pct',		0,          0,
				0,          0,          0, 
				0,          0,          0, 
				0,          0,          0, 	
   			0,          0,          1)

		  INSERT INTO #RESULT
		  (  CDate,			CTtl,			COpen,		
			 CAllocated,	CPacked,		CShipped, 	
			 CCancelled,	TOpen,			TAllocated, 
			 TPacked,		TShipped,		TCancelled,	
			 Header,		AddHour,		SeqNo)
		   VALUES (
			  'Total',		0,          0,
				0,          0,          0, 
				0,          0,          0, 
				0,          0,          0, 	
   			0,          0,          2) 
   	    
		END

	   GOTO RESULT_OUTPUT
	END
-- End Dummy Record --
 
   SELECT TOP 1 @d_Last_Date = osss.[DATETIME] 
   FROM   V_DtsItf_Orders_SUM_SnapShot AS osss WITH (NOLOCK)
   ORDER BY osss.Rowref DESC

   SET @nCounter = 8
   SET @n_Interval  = 1
   SET @d_Last_Date = DATEADD(hour, ((@n_Interval * (@nCounter - 1)) * -1), @d_Last_Date) 

   SET @n_Count = 1
   WHILE @n_Count <= @nCounter
   BEGIN
	   SET @n_Next_Hour = DATEPART(hour, @d_Last_Date)
	   SET @c_Next_Date = CONVERT(VARCHAR(10), @d_Last_Date, 112) 
	
	   SET @d_Start_Date = CONVERT(VARCHAR(10), @d_Last_Date, 112) + ' ' + RIGHT('0' + CAST(@n_Next_Hour AS VARCHAR(2)), 2) + ':00' 
	   SET @d_End_Date =   CONVERT(VARCHAR(10), @d_Last_Date, 112) + ' ' + RIGHT('0' + CAST(@n_Next_Hour + @n_Interval - 1 AS VARCHAR(2)), 2) + ':59' 

      SELECT
        @nTotalOrder = 0
      , @nTotalOpen  = 0
      , @nTotalAlloc = 0
      , @nTotalPick  = 0
      , @nTotalShip  = 0
      , @nTotalCanc  = 0
	
	   SET @cHour = RIGHT('0' + CAST(@n_Next_Hour AS VARCHAR(2)), 2) + ':00'
	   
	   SELECT TOP 1  
	      @d_Next_Date = osss.[DATETIME], 
         @nHour       = DATEPART(hour, osss.[DATETIME]) 
      FROM  V_DtsItf_Orders_SUM_SnapShot AS osss WITH (NOLOCK) 
	   WHERE osss.[DATETIME] BETWEEN @d_Start_Date AND @d_End_Date 
	   AND   EXISTS(SELECT 1 FROM  [API].[UserRestrictions] As US WITH (NOLOCK) 
				           WHERE US.[UserName] = @c_UserName 
							  AND   US.[Restrictions] = 'STORER' 
							  AND  (US.[Value] = '(ALL)' OR osss.StorerKey = US.VALUE))
	   ORDER BY osss.Rowref DESC


	   SELECT @nTotalOpen  = SUM(osss.TTL_Orders_Open)
      FROM  V_DtsItf_Orders_SUM_SnapShot AS osss WITH (NOLOCK) 
	   WHERE osss.[DATETIME] = @d_Next_Date
	   AND   EXISTS(SELECT 1 FROM  [API].[UserRestrictions] As US WITH (NOLOCK) 
				           WHERE US.[UserName] = @c_UserName 
							  AND   US.[Restrictions] = 'STORER' 
							  AND  (US.[Value] = '(ALL)' OR osss.StorerKey = US.VALUE))
                  
      SELECT 
            @nTotalOrder   = SUM(osss.num_Orders_Added),              
            @nTotalAlloc   = SUM(osss.num_Orders_Allocated), 
            @nTotalPick    = SUM(osss.num_Orders_Pick_Packed), 
            @nTotalShip    = SUM(osss.num_Orders_Shipped), 
            @nTotalCanc    = SUM(osss.num_Orders_Cancelled) 
         FROM V_DtsItf_Orders_SUM_SnapShot AS osss WITH (NOLOCK)		   
         WHERE osss.[DATETIME] BETWEEN @d_Start_Date AND @d_End_Date
         AND   EXISTS(SELECT 1 FROM  [API].[UserRestrictions] As US WITH (NOLOCK) 
				           WHERE US.[UserName] = @c_UserName 
							  AND   US.[Restrictions] = 'STORER' 
							  AND  (US.[Value] = '(ALL)' OR osss.StorerKey = US.VALUE))

      SET @nVarTotalOrder = 0
      SET @nVarTotalOpen  = 0
      SET @nVarTotalAlloc = 0
      SET @nVarTotalPick  = 0
      SET @nVarTotalShip  = 0
      SET @nVarTotalCanc  = 0

      SET @nVarTotalOrder = ISNULL(@nTotalOrder, 0) - ISNULL(@nPrevTotalOrder, 0)
      SET @nVarTotalOpen  = ISNULL(@nTotalOpen , 0) - ISNULL(@nPrevTotalOpen , 0)
      SET @nVarTotalAlloc = ISNULL(@nTotalAlloc, 0) - ISNULL(@nPrevTotalAlloc, 0)
      SET @nVarTotalPick  = ISNULL(@nTotalPick , 0) - ISNULL(@nPrevTotalPick , 0)
      SET @nVarTotalShip  = ISNULL(@nTotalShip , 0) - ISNULL(@nPrevTotalShip , 0)
      SET @nVarTotalCanc  = ISNULL(@nTotalCanc , 0) - ISNULL(@nPrevTotalCanc , 0)
    	
	   INSERT INTO #RESULT
	   ( CDate,		   CTtl,		   COpen,		
	     CAllocated,	CPacked,    CShipped, 	
	     CCancelled,	TOpen,      TAllocated, 
        TPacked,     TShipped,   TCancelled,  	
	     Header,		AddHour,		SeqNo)
	   VALUES 
	      (ISNULL(@cHour,0),             ISNULL(@nTotalOrder,0),     ISNULL(@nVarTotalOpen,0),
	       ISNULL(@nVarTotalAlloc,0),    ISNULL(@nVarTotalPick,0),   ISNULL(@nVarTotalShip,0),	          
	       ISNULL(@nVarTotalCanc,0),     ISNULL(@nTotalOpen,0),      ISNULL(@nTotalAlloc,0), 
	       ISNULL(@nTotalPick,0),        ISNULL(@nTotalShip,0),      ISNULL(@nTotalCanc,0), 
	       @n_Count,           @nHour, 
	       @nCounter - @n_Count)
              	      
      SET @nPrevTotalOrder = @nTotalOrder
      SET @nPrevTotalOpen  = @nTotalOpen
      SET @nPrevTotalAlloc = @nTotalAlloc
      SET @nPrevTotalPick  = @nTotalPick
      SET @nPrevTotalShip  = @nTotalShip
      SET @nPrevTotalCanc  = @nTotalCanc
      	
	   SET @d_Last_Date = DateAdd(hour, @n_Interval, @d_Last_Date)
	   SET @n_Count = @n_Count + 1 
   END -- WHILE @n_Count <= @nCounter

   DECLARE @dt_LastExtracion DATETIME
    
   SELECT @dt_LastExtracion = MAX(DATETIME)  
   FROM  V_DtsItf_Orders_SUM_SnapShot AS osss WITH (NOLOCK)
   WHERE EXISTS(SELECT 1 FROM  [API].[UserRestrictions] As US WITH (NOLOCK) 
				           WHERE US.[UserName] = @c_UserName 
							  AND   US.[Restrictions] = 'STORER' 
							  AND  (US.[Value] = '(ALL)' OR osss.StorerKey = US.VALUE))
    
   SELECT @nTotalOrder   = ISNULL(SUM(osss.TTL_Orders),0),  
          @nTotalOpen    = ISNULL(SUM(osss.TTL_Orders_Open),0),
          @nTotalAlloc   = ISNULL(SUM(osss.TTL_Orders_ALLOC),0), 
          @nTotalPick    = ISNULL(SUM(osss.TTL_Orders_Pick_Packed),0), 
          @nTotalShip    = ISNULL(SUM(osss.TTL_Orders_Shipped),0), 
          @nTotalCanc    = ISNULL(SUM(osss.TTL_Orders_Cancelled),0)  
   FROM  V_DtsItf_Orders_SUM_SnapShot AS osss WITH (NOLOCK) 
   WHERE [DATETIME]=@dt_LastExtracion     
   AND   EXISTS(SELECT 1 FROM  [API].[UserRestrictions] As US WITH (NOLOCK) 
				         WHERE US.[UserName] = @c_UserName 
							AND   US.[Restrictions] = 'STORER' 
							AND  (US.[Value] = '(ALL)' OR osss.StorerKey = US.VALUE))
   IF @nTotalOrder > 0 
   BEGIN
      INSERT INTO #RESULT
      ( CDate,		   CTtl,		   COpen,		
	      CAllocated,	CPacked,    CShipped, 	
	      CCancelled,	TOpen,      TAllocated, 
         TPacked,    TShipped,   TCancelled,	
	      Header,		AddHour,		SeqNo)
	      VALUES (
	      'Pct',
	      0, 	
         ((@nTotalOpen  / (@nTotalOrder * 1.00)) * 100.00),	
         ((@nTotalAlloc / (@nTotalOrder * 1.00)) * 100.00),	
         ((@nTotalPick  / (@nTotalOrder * 1.00)) * 100.00),	
         ((@nTotalShip  / (@nTotalOrder * 1.00)) * 100.00),	
         ((@nTotalCanc  / (@nTotalOrder * 1.00)) * 100.00),
         0,0,0,0,0,
         @n_Count,         
         @nHour, 
         0)	   

      INSERT INTO #RESULT
      (  CDate,		   CTtl,		   COpen,		
	      CAllocated,	CPacked,    CShipped, 	
	      CCancelled,	TOpen,      TAllocated, 
         TPacked,    TShipped,   TCancelled,		
	      Header,		AddHour,		SeqNo)
	      VALUES (
	      'Total',
	      @nTotalOrder, 	
         @nTotalOpen ,	
         @nTotalAlloc,	
         @nTotalPick ,	
         @nTotalShip ,	
         @nTotalCanc ,
         0,0,0,0,0,
         @n_Count,         
         @nHour, 
         0 )
   	
   END         
   ELSE
   BEGIN
      INSERT INTO #RESULT
      (  CDate,		   CTtl,		   COpen,		
	      CAllocated,	CPacked,    CShipped, 	
	      CCancelled,	TOpen,      TAllocated, 
         TPacked,    TShipped,   TCancelled,	
	      Header,		AddHour,		SeqNo)
	      VALUES (
	      'Pct',	   0,          0,
	      0,          0,          0, 
	      0,          0,          0, 
	      0,          0,          0, 	
   	   0,          0,          1)

      INSERT INTO #RESULT
      (  CDate,		   CTtl,		   COpen,		
	      CAllocated,	CPacked,    CShipped, 	
	      CCancelled,	TOpen,      TAllocated, 
         TPacked,    TShipped,   TCancelled,	
	      Header,		AddHour,		SeqNo)
	      VALUES (
	      'Total',	   0,          0,
	      0,          0,          0, 
	      0,          0,          0, 
	      0,          0,          0, 	
   	   0,          0,          2) 
   	
   END
	
	RESULT_OUTPUT:     

   SELECT IDENTITY(int, 1,1) AS ID_Num, 
          CDate, 
          CTtl, 
          CASE WHEN CDate <> 'Pct' THEN CONVERT(NVARCHAR(10), CAST(COpen AS INT)) ELSE CONVERT(NVARCHAR(10), COpen) + '%' END AS COpen, 
          CASE WHEN CDate <> 'Pct' THEN CONVERT(NVARCHAR(10), CAST(CAllocated AS INT)) ELSE CONVERT(NVARCHAR(10), CAllocated) + '%' END AS CAllocated, 
          CASE WHEN CDate <> 'Pct' THEN CONVERT(NVARCHAR(10), CAST(CPacked AS INT)) ELSE CONVERT(NVARCHAR(10), CPacked) + '%' END AS CPacked, 
          CASE WHEN CDate <> 'Pct' THEN CONVERT(NVARCHAR(10), CAST(CShipped AS INT)) ELSE CONVERT(NVARCHAR(10), CShipped) + '%' END AS CShipped, 
          CASE WHEN CDate <> 'Pct' THEN CONVERT(NVARCHAR(10), CAST(CCancelled AS INT)) ELSE CONVERT(NVARCHAR(10), CCancelled) + '%' END AS CCancelled,
          CONVERT(NVARCHAR(10), CAST(TOpen AS INT)) AS TOpen,      
          CONVERT(NVARCHAR(10), CAST(TAllocated AS INT)) AS TAllocated, 
          CONVERT(NVARCHAR(10), CAST(TPacked AS INT)) AS TPacked,    
          CONVERT(NVARCHAR(10), CAST(TShipped AS INT)) AS TShipped,   
          CONVERT(NVARCHAR(10), CAST(TCancelled AS INT)) AS TCancelled,
          Header, 
          AddHour, 
          SeqNo
   INTO #B          
   FROM #RESULT  
   ORDER BY RowNo DESC

      	
   SELECT @c_RespString = API.fnc_FlattenedJSON(( SELECT * FROM #B FOR XML path, root))
   
END

GO