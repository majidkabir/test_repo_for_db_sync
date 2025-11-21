SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrPickDetailPreDelete                                      */
/* Creation Date: 2024-06-04                                            */
/* Copyright: Maersk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: UWP-18393 - Unallocation for Mixed Sku Pallet               */
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
/* Called By: When records INSERTED                                     */
/*                                                                      */
/* GITHUB Version: 1.1                                                  */
/*                                                                      */
/* Version: 2                                                           */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   ver   Purposes                                  */
/* 2024-06-04  Wan      1.0   Created.                                  */
/* 2024-06-21  Wan01    1.1   UWP-18393 - Fixed                         */
/************************************************************************/
CREATE   TRIGGER [dbo].[ntrPickDetailPreDelete]
ON  [dbo].[PICKDETAIL]
INSTEAD OF DELETE  
AS
BEGIN
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END 

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
 
   DECLARE
           @n_StartTCnt       INT            = @@TRANCOUNT
         , @n_Continue        INT            = 1   
         , @b_Success         INT            = 1 -- Populated by calls to stored procedures - was the proc successful?
         , @n_err             INT            = 0 -- Error number returned by stored procedure or this trigger
         , @c_errmsg          NVARCHAR(250)  = ''-- Error message returned by stored procedure or this trigger
         , @c_Facility        NVARCHAR(5)  = ''
         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_LockedID        NVARCHAR(10) = '' 
         , @c_Loc             NVARCHAR(10) = ''          
         , @c_ID              NVARCHAR(18) = ''                            
                         
         , @CUR_ID            CURSOR                                       
 
   IF EXISTS( SELECT 1 FROM DELETED WHERE ArchiveCop = '9')
      SET @n_Continue = 4

   IF OBJECT_ID('tempdb..#tmpPICKDETAIL','u') IS NOT NULL
   BEGIN
      DROP TABLE #tmpPICKDETAIL;
   END

   CREATE TABLE #tmpPICKDETAIL (PickDetailKey  NVARCHAR(10)   NOT NULL PRIMARY KEY)

   INSERT INTO #tmpPICKDETAIL (Pickdetailkey)
   SELECT Pickdetailkey FROM deleted d

   IF @n_continue IN (1, 2) 
   BEGIN
      SET @CUR_ID = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT d.Storerkey, d.Loc, d.ID 
      FROM DELETED d
      JOIN PICKDETAIL pd (NOLOCK) ON  pd.Storerkey = d.Storerkey      
                                  AND pd.ID = d.ID
      JOIN SKUxLOC sl (NOLOCK) ON  sl.Storerkey = d.Storerkey
                               AND sl.Sku = d.Sku
                               AND sl.Loc = d.Loc
      JOIN LOC l (NOLOCK) ON l.loc = d.loc
      CROSS APPLY dbo.fnc_SelectGetRight (l.Facility, d.storerkey, '', 'StockOnLockedID') sc --(Wan01)
      WHERE d.[Status] < '9'
      AND sl.LocationType NOT IN ('CASE', 'PICK')
      AND l.Loc NOT IN ('DYNPPICK','DYNPICKP','DYNPICKR')
      AND sc.Authority = '1'
      GROUP BY d.Storerkey, d.Loc, d.ID
      ORDER BY d.Storerkey, d.Loc, d.ID

      OPEN @CUR_ID

      FETCH NEXT FROM @CUR_ID INTO @c_Storerkey, @c_Loc, @c_ID

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1, 2)
      BEGIN
         INSERT INTO #tmpPICKDETAIL (Pickdetailkey)
         SELECT pd.PickDetailKey
         FROM PICKDETAIL pd (NOLOCK) 
         LEFT OUTER JOIN DELETED d ON  d.PickDetailKey = pd.PickDetailKey      
         WHERE pd.Storerkey = @c_Storerkey
         AND   pd.Loc = @c_Loc
         AND   pd.ID = @c_ID
         AND   pd.[Status] < '9'
         AND   d.PickDetailKey IS NULL

         FETCH NEXT FROM @CUR_ID INTO @c_Storerkey, @c_Loc, @c_ID
      END
      CLOSE @CUR_ID
      DEALLOCATE @CUR_ID
   END

   DELETE P 
   FROM PICKDETAIL P
   JOIN #tmpPICKDETAIL d ON p.PickDetailKey = d.PickDetailKey
END -- Trigger

GO