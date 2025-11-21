SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispOrderBatching2                                  */  
/* Creation Date: 21-Jan-2014                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Chee Jun Yan                                             */  
/*                                                                      */  
/* Purpose: Assign Batch Number to orders within Load based on passed   */  
/*          parameters value:                                           */  
/*          @n_OrderCount - Number of orders per batch                  */  
/*          @c_PickZones  - Assign batch based on pickzone given        */  
/*                          [ZoneA,ZoneB,ZoneC,ZoneD (Comma delimited)] */  
/*          @c_Mode:                                                    */  
/*          0 - Normal, assign based on ordercount and pick zones given */  
/*          1 - Only batch order with total qty > 1 and with single     */  
/*              pickzone                                                */  
/*          2 - Only batch order with total qty > 1 and with multiple   */  
/*              pickzone                                                */  
/*          3 - Only batch order with total qty > 1 including single    */  
/*              and multiple pickzone                                   */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/* 21-01-2014   Chee    1.0   Initial Version                           */  
/* 18-06-2014   Chee    1.1   Bug Fix - Clear Diff for new batch        */  
/*                            Show error message when no result (Chee01)*/  
/* 04-07-2014   Chee    1.2   Filter by mode first, before filter by    */  
/*                            pickzone (Chee02)                         */  
/* 23-07-2014   Chee    1.3   Update PickDetail.Notes = Pickzone + '-'  */  
/*                            + Batch + ':' + Mode (Chee03)             */  
/* 30-07-2014   Chee    1.4   Add leading zeros to batch number, for    */  
/*                            sorting purpose (Chee04)                  */  
/************************************************************************/  
CREATE PROC [dbo].[ispOrderBatching2]    
     @c_LoadKey     NVARCHAR(10)  
   , @n_OrderCount  INT  
   , @c_PickZones   NVARCHAR(4000)  
   , @c_Mode        NVARCHAR(1) = '0'   
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT  
AS    
BEGIN    
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
  
   DECLARE    
      @n_Continue   INT,    
      @n_StartTCnt  INT, -- Holds the current transaction count     
      @c_OrderKey   NVARCHAR(10),   
      @n_Counter    INT,   
      @n_BatchNo    INT,   
      @n_Count      INT,  
      @c_PickZone   NVARCHAR(10),  
      @b_debug      INT,  
      @b_Found      INT   -- (Chee01)  
      
      
  
   DECLARE @t_OrderTable TABLE (  
      OrderKey  NVARCHAR(10),  
      Loc       NVARCHAR(10),  
      Score     INT,  
      Qty       INT,  
      Diff      INT  
   )  
  
   DECLARE @t_BatchResultTable TABLE (  
      BatchNo   NVARCHAR(10),  
      OrderKey  NVARCHAR(10),  
      Loc       NVARCHAR(10),  
      Score     INT,  
      Status    NCHAR(1) DEFAULT '0'  
   )  
  
   DECLARE @t_PickZoneTable TABLE(  
      PickZone NVARCHAR(10)  
   )  
  
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0  
   SELECT @c_ErrMsg=''  
   SELECT @b_debug = 1,   
          @b_Found = 0  -- (Chee01)  
  
   IF ISNULL(@c_LoadKey, '') = ''  
   BEGIN  
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63500    
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': LoadKey is empty. (ispOrderBatching)'   
      GOTO Quit  
   END  
  
   IF NOT EXISTS(SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK) WHERE LoadKey = @c_LoadKey)  
   BEGIN  
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63501   
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid LoadKey. (ispOrderBatching)'   
      GOTO Quit  
   END  
  
   IF ISNULL(@n_OrderCount, 0) <= 0  
   BEGIN  
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63502   
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Order count must be larger than zero. (ispOrderBatching)'   
      GOTO Quit  
   END  
  
   WHILE CHARINDEX(',', @c_PickZones) > 0  
   BEGIN  
      SET @n_Count = CHARINDEX(',', @c_PickZones)    
      INSERT INTO @t_PickZoneTable VALUES (LTRIM(RTRIM(SUBSTRING(@c_PickZones, 1, @n_Count-1))))  
      SET @c_PickZones = SUBSTRING(@c_PickZones, @n_Count+1, LEN(@c_PickZones)-@n_Count)  
   END   
   INSERT INTO @t_PickZoneTable VALUES (LTRIM(RTRIM(@c_PickZones)))  
  
   BEGIN TRAN  


     -- Assign batch based on pickzone given  
   DECLARE C_PICKZONE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PickZone FROM @t_PickZoneTable  
  
   OPEN C_PICKZONE  
   FETCH NEXT FROM C_PICKZONE INTO @c_PickZone  
  
   WHILE (@@FETCH_STATUS <> -1)            
   BEGIN   
      INSERT INTO @t_OrderTable (OrderKey, Loc, Score, Qty)  
      SELECT PD.OrderKey, L.LOC, ISNULL(L.Score, 0) AS Score, SUM(PD.Qty) AS Qty  
      FROM PickDetail PD (NOLOCK)  
      JOIN LOADPLANDETAIL LPD ON (LPD.OrderKey = PD.OrderKey)  
      JOIN LOC L ON (L.LOC = PD.LOC)  
      WHERE LPD.LoadKey = @c_LoadKey  
      --  AND L.PickZone = @c_PickZone  -- (Chee02)  
        AND ISNULL(L.Score, 0) > 0  
      GROUP BY PD.OrderKey, L.LOC, ISNULL(L.Score, 0)  
  
        SELECT PD.OrderKey, L.LOC, ISNULL(L.Score, 0) AS Score, SUM(PD.Qty) AS Qty  
      FROM PickDetail PD (NOLOCK)  
      JOIN LOADPLANDETAIL LPD ON (LPD.OrderKey = PD.OrderKey)  
      JOIN LOC L ON (L.LOC = PD.LOC)  
      WHERE LPD.LoadKey = @c_LoadKey  
      --  AND L.PickZone = @c_PickZone  -- (Chee02)  
        AND ISNULL(L.Score, 0) > 0  
      GROUP BY PD.OrderKey, L.LOC, ISNULL(L.Score, 0)  
      
      IF @c_Mode IN ('1', '2', '3')  
      BEGIN  
         -- Exclude orders with total qty <= 1  
         DELETE FROM @t_OrderTable  
         WHERE OrderKey IN (SELECT OrderKey   
                            FROM @t_OrderTable   
                            GROUP BY OrderKey   
                            HAVING SUM(Qty) <= 1)  
         IF @c_Mode = '1'  
         BEGIN  
            -- Exclude orders with multi pickzone  
            DELETE FROM @t_OrderTable  
            WHERE OrderKey IN (SELECT O.OrderKey  
                               FROM @t_OrderTable O   
                               JOIN PickDetail PD (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
                               JOIN LOC L ON (L.LOC = PD.LOC)  
                               WHERE ISNULL(L.PickZone, '') <> ''  
                                 AND ISNULL(L.Score, 0) > 0  
                               GROUP BY O.OrderKey   
                               HAVING COUNT(DISTINCT L.PickZone) > 1)  
         END  
         ELSE IF @c_Mode = '2'  
         BEGIN  
            -- Exclude orders with single pickzone  
            DELETE FROM @t_OrderTable  
            WHERE OrderKey IN (SELECT O.OrderKey  
                               FROM @t_OrderTable O   
                               JOIN PickDetail PD (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
                               JOIN LOC L ON (L.LOC = PD.LOC)  
                               WHERE ISNULL(L.PickZone, '') <> ''  
                                 AND ISNULL(L.Score, 0) > 0  
                               GROUP BY O.OrderKey   
                               HAVING COUNT(DISTINCT L.PickZone) = 1)  
         END  
      END -- IF @c_Mode IN ('1', '2', '3')  
 
      -- (Chee02)  
  DELETE @t_OrderTable  
      FROM @t_OrderTable O  
      JOIN LOC L ON (L.LOC = O.LOC)  
      WHERE L.PickZone <> @c_PickZone  
  
      SELECT   
        @n_Count = COUNT(1),   
        @n_Counter = 1,   
        @n_BatchNo = 1  
      FROM @t_OrderTable  
        
      WHILE (@n_Count > 0)  
      BEGIN  
         IF @n_Counter = 1  
         BEGIN  
            -- Clear Diff field for each new batch (Chee01)  
            UPDATE @t_OrderTable SET Diff = NULL  
  
            IF @b_debug = 1  
            BEGIN  
               SELECT 'RESTART'  
               SELECT * FROM @t_OrderTable ORDER BY Score, OrderKey  
            END  
  
            SELECT TOP 1   
               @c_OrderKey = OrderKey  
            FROM @t_OrderTable O  
            ORDER BY Score, OrderKey  
         END  
         ELSE  
         BEGIN  
--            SELECT TOP 1   
--               @c_OrderKey = OrderKey  
--            FROM (  
--               SELECT OrderKey, Score, MIN(ABS(Score-RScore)) AS Diff  
--               FROM (  
--                  SELECT O.OrderKey, O.Score , R.Score AS RScore  
--                  FROM @t_OrderTable O  
--                  CROSS JOIN @t_BatchResultTable R  
--                  WHERE R.Status <> '9'  
--                  GROUP BY O.OrderKey, O.Score, R.Score  
--               ) AS A  
--               Group BY OrderKey, Score  
--            ) AS B  
--            GROUP BY OrderKey   
--            ORDER BY AVG(CAST(Diff AS FLOAT))  
  
            UPDATE @t_OrderTable  
            SET Diff = B.Diff  
            FROM @t_OrderTable O  
            JOIN (  
               SELECT   
                  OrderKey, Loc, Score,   
                  CASE WHEN ODiff <= MIN(ABS(Score-RScore)) THEN ODiff   
                       ELSE MIN(ABS(Score-RScore))   
                  END AS Diff  
               FROM (  
                  SELECT O.OrderKey, O.Loc, O.Score, O.Diff AS ODiff, R.Score AS RScore  
                  FROM @t_OrderTable O  
                  CROSS JOIN @t_BatchResultTable R  
                  WHERE R.Status <> '9'  
                  GROUP BY O.OrderKey, O.Loc, O.Diff, O.Score, R.Score  
               ) AS A  
               Group BY OrderKey, Loc, Score, ODiff  
            ) AS B  
            ON O.OrderKey = B.OrderKey AND O.Loc = B.Loc  
  
            SELECT TOP 1   
               @c_OrderKey = OrderKey  
            FROM @t_OrderTable  
            GROUP BY OrderKey   
            ORDER BY AVG(CAST(Diff AS FLOAT))  
         END  
  
         UPDATE @t_BatchResultTable   
         SET Status = '9'  
  
         INSERT INTO @t_BatchResultTable (BatchNo, OrderKey, Loc, Score)   
         SELECT  
            CAST(@n_BatchNo AS NVARCHAR),  
            OrderKey,   
            Loc,  
            Score  
         FROM @t_OrderTable O  
         WHERE OrderKey = @c_OrderKey  
  
         DELETE FROM @t_OrderTable  
         WHERE OrderKey = @c_OrderKey  
  
         SET @n_Counter = @n_Counter + 1  
  
         SELECT @n_Count = COUNT(1)   
         FROM @t_OrderTable  
  
         IF @n_Counter > @n_OrderCount  
         BEGIN  
            IF @b_debug = 1  
            BEGIN  
               SELECT 'DONE BatchNo: ' + CAST(@n_BatchNo AS NVARCHAR)  
               SELECT * FROM @t_BatchResultTable  
            END  
  
            SET @n_BatchNo = @n_BatchNo + 1  
            SET @n_Counter = 1  
  
            -- (Chee01)  
            IF @b_Found = 0  
               SET @b_Found = 1  
  
            UPDATE PickDetail WITH (ROWLOCK)  
            SET Notes = @c_PickZone + '-' + RIGHT('000' + R.BatchNo, 3) + ':' + @c_Mode   -- (Chee03, Chee04)  
              , TrafficCop = NULL   
            FROM PickDetail PD  
            JOIN @t_BatchResultTable R ON PD.OrderKey = R.OrderKey AND PD.Loc = R.Loc  
  
            IF @@ERROR <> 0  
            BEGIN  
               SELECT @n_Continue = 3    
               SELECT @n_Err = 63503    
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update PickDetail. (ispOrderBatching)'  
               GOTO Quit   
            END  
  
       DELETE FROM @t_BatchResultTable  
         END  
      END  
  
      IF EXISTS(SELECT 1 FROM @t_BatchResultTable)  
      BEGIN  
         -- (Chee01)  
         IF @b_Found = 0  
            SET @b_Found = 1  
  
         UPDATE PickDetail WITH (ROWLOCK)  
         SET Notes = @c_PickZone + '-' + RIGHT('000' + R.BatchNo, 3) + ':' + @c_Mode   -- (Chee03, Chee04)  
           , TrafficCop = NULL  
         FROM PickDetail PD  
         JOIN @t_BatchResultTable R ON PD.OrderKey = R.OrderKey AND PD.Loc = R.Loc    
  
         IF @@ERROR <> 0  
         BEGIN  
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63504   
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update PickDetail. (ispOrderBatching)'   
            GOTO Quit  
         END  
  
         DELETE FROM @t_BatchResultTable  
      END  
  
      FETCH NEXT FROM C_PICKZONE INTO @c_PickZone  
   END    
   CLOSE C_PICKZONE           
   DEALLOCATE C_PICKZONE  
  
   -- Show Error when no result found (Chee01)  
   IF @b_Found = 0  
   BEGIN  
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63505   
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': No result within PickZone. (ispOrderBatching)'   
      GOTO Quit  
   END  
     
Quit:  
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_StartTCnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispOrderBatching'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
    
END -- Procedure  

GO