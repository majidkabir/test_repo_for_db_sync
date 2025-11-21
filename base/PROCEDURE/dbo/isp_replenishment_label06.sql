SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_replenishment_label06                               */
/* Creation Date: 16-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4851 - CN_CNA_Replenishment Label_New                   */
/*        :                                                             */
/* Called By: r_dw_replenishment_label06                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_replenishment_label06]
           @c_StorerKey NVARCHAR(15)
         , @c_WaveKey   NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt    INT
         , @n_Continue     INT 

         , @c_Sku          NVARCHAR(20)
         , @c_FromLoc      NVARCHAR(10)
         , @c_ToLoc        NVARCHAR(10)
         , @c_PutawayZone  NVARCHAR(10)
         , @n_ReplenQty    INT
         , @n_CaseCnt      FLOAT
         , @n_NoOfLabel    INT
         , @n_Cnt          INT
         , @n_LabelQty     INT

         , @CUR_REPLLBL    CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_WaveKey = ISNULL(RTRIM(@c_WaveKey), '')
      
   CREATE TABLE #TMP_REPLLBL
      (  RowNo       INT   IDENTITY (1,1) PRIMARY KEY
      ,  Storerkey   NVARCHAR(15)   NULL
      ,  Sku         NVARCHAR(20)   NULL
      ,  FromLoc     NVARCHAR(10)   NULL
      ,  ToLoc       NVARCHAR(10)   NULL
      ,  PutawayZone NVARCHAR(10)   NULL
      ,  CaseCnt     FLOAT          NULL
      ,  LabelQty    INT            NULL
      )


   SET @CUR_REPLLBL = CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT RP.Sku
         ,RP.FromLoc
         ,RP.ToLoc
         ,LOC.PutawayZone
         ,ReplenQty = SUM(RP.Qty)
         ,PACK.CaseCnt
   FROM REPLENISHMENT RP WITH (NOLOCK)  
   JOIN LOC              WITH (NOLOCK) ON (RP.FromLoc = LOC.Loc)
   JOIN PACK             WITH (NOLOCK) ON (RP.Packkey = PACK.Packkey)
   WHERE RP.Storerkey = @c_Storerkey
   AND   RP.Wavekey   = CASE WHEN @c_Wavekey = '' THEN RP.Wavekey ELSE @c_WaveKey END
   AND   RP.Confirmed <> 'Y'
   GROUP BY RP.Sku
         ,  RP.FromLoc
         ,  RP.ToLoc
         ,  LOC.PutawayZone
         ,  PACK.CaseCnt
   ORDER BY RP.FromLoc
         ,  RP.ToLoc

   OPEN @CUR_REPLLBL
   FETCH NEXT FROM @CUR_REPLLBL INTO  @c_Sku        
                                    , @c_FromLoc      
                                    , @c_ToLoc        
                                    , @c_PutawayZone  
                                    , @n_ReplenQty  
                                    , @n_CaseCnt   

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_NoOfLabel = 1

      IF @n_CaseCnt > 0
      BEGIN
         SET @n_NoOfLabel = CEILING ( @n_ReplenQty / @n_CaseCnt)
      END
     
      SET @n_Cnt = 0
      WHILE @n_Cnt < @n_NoOfLabel
      BEGIN
         SET @n_Cnt = @n_Cnt + 1
         SET @n_LabelQty = 0

         IF @n_CaseCnt = 0 
         BEGIN
            SET @n_LabelQty = @n_ReplenQty 
         END
         ELSE
         BEGIN  
            IF @n_ReplenQty >= @n_CaseCnt 
            BEGIN 
               SET @n_LabelQty = @n_CaseCnt
               SET @n_ReplenQty = @n_ReplenQty - @n_CaseCnt
            END
            ELSE
            BEGIN
               SET @n_LabelQty = @n_ReplenQty % CONVERT(NUMERIC(12,2), @n_CaseCnt)
            END 
         END

         INSERT INTO #TMP_REPLLBL
            (  
               Storerkey
            ,  Sku          
            ,  FromLoc      
            ,  ToLoc        
            ,  PutawayZone  
            ,  CaseCnt     
            ,  LabelQty
            )
         VALUES 
            (  
               @c_StorerKey
            ,  @c_Sku          
            ,  @c_FromLoc      
            ,  @c_ToLoc        
            ,  @c_PutawayZone  
            ,  @n_CaseCnt
            ,  @n_LabelQty    
            )

      END
      
      FETCH NEXT FROM @CUR_REPLLBL INTO  @c_Sku        
                                       , @c_FromLoc      
                                       , @c_ToLoc        
                                       , @c_PutawayZone  
                                       , @n_ReplenQty 
                                       , @n_CaseCnt    
   END
   CLOSE @CUR_REPLLBL
   DEALLOCATE @CUR_REPLLBL  

   QUIT_SP:

   SELECT   RowNo
         ,  Storerkey
         ,  Sku          
         ,  FromLoc      
         ,  ToLoc        
         ,  PutawayZone
         ,  CaseCnt     
         ,  LabelQty 
         ,  PrintDate = GetDate()    
   FROM #TMP_REPLLBL
   
END -- procedure

GO