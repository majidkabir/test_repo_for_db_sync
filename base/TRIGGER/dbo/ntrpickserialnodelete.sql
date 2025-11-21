SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Trigger: ntrPickSerialNoDelete                                       */    
/* Creation Date: 2024-11-26                                            */    
/* Copyright: Maersk Logistics                                          */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: PackSerialNo Delete trigger                                 */
/*                                                                      */
/* Called By: UWP-23317 - [FCR-618 819] Unpick SerialNo                 */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date           Author   Ver.  Purposes                               */   
/************************************************************************/    

CREATE   TRIGGER [ntrPickSerialNoDelete] ON [PickSerialNo] 
FOR DELETE
AS
BEGIN
   IF @@ROWCOUNT = 0
      RETURN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success            int = 1           -- Populated by calls to stored procedures - was the proc successful?      
         , @n_err                int = 0           -- Error number returned by stored procedure or this trigger      
         , @c_errmsg             NVARCHAR(250)=''  -- Error message returned by stored procedure or this trigger      
         , @n_continue           int = 1           -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing      
         , @n_starttcnt          int = @@TRANCOUNT -- Holds the current transaction count      
        
         , @n_Qty                INT = 0
         , @n_Qty_PD             INT = 0
         , @c_PickDetailKey      NVARCHAR(10) = ''
         , @c_NewPickDetailKey   NVARCHAR(10) = ''
         , @c_SerialNoKey        NVARCHAR(10) = ''
         , @c_PickStatus         NVARCHAR(10) = ''
         , @c_PackStatus         NVARCHAR(10) = ''
 
         , @CUR_PSNO             CURSOR
         , @CUR_UPDPD            CURSOR

   SET @b_success =  0
   SET @n_err     =  0
   SET @c_errmsg  =  ''
        
   if (SELECT COUNT(1) FROM DELETED)  = 
      (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9') 
   BEGIN
      SET @n_continue = 4
   END

   IF OBJECT_ID('tempdb..#TMP_SERIALDEL','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_SERIALDEL;
   END
    
   CREATE TABLE #TMP_SERIALDEL
   (  SerialNoKey       NVARCHAR(10)   NOT NULL PRIMARY KEY
   ,  SerialNo          NVARCHAR(30)   NOT NULL DEFAULT ('')
   ,  PickDetailKey     NVARCHAR(10)   NOT NULL DEFAULT ('')
   ,  PickStatus        NVARCHAR(10)   NOT NULL DEFAULT ('5')
   )

   INSERT INTO #TMP_SERIALDEL 
   ( SerialNoKey, SerialNo, PickDetailKey, PickStatus)
   SELECT sn.SerialNoKey, d.SerialNo, pd.PickDetailKey, [Status] = '0'
   FROM DELETED d
   JOIN SerialNo sn (NOLOCK) ON sn.SerialNo = d.SerialNo
   JOIN PICKDETAIL pd WITH (NOLOCK) ON pd.PickDetailKey = d.PickDetailKey
   WHERE d.SerialNo > ''
   AND pd.[Status] <= '5'
   UNION
   SELECT sn.SerialNoKey, d.SerialNo, PickDetailKey = '', [Status] = '5'            --if call from ntrpickdetaildelete trigger
   FROM DELETED d
   JOIN SerialNo sn (NOLOCK) ON sn.SerialNo = d.SerialNo
   LEFT OUTER JOIN PICKDETAIL pd WITH (NOLOCK) ON  pd.PickDetailKey = d.PickDetailKey
   WHERE d.SerialNo > ''
   AND   pd.PickDetailKey IS NULL

   -- Check Pickdetail is shipped 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(  SELECT TOP 1 1 
                  FROM DELETED d
                  JOIN #TMP_SERIALDEL sn ON sn.SerialNo = d.SerialNo
                  JOIN PICKDETAIL pd WITH (NOLOCK) ON  pd.PickDetailKey = d.PickDetailKey
                  WHERE (pd.[Status] = '9' OR pd.ShipFlag = 'Y')
               )   
      BEGIN
         SET @n_continue = 3
         SET @n_err = 68010
         SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Delete fail due to Pick is Shipped (ntrPickSerialNoDelete)'
      END
   END

   -- Check SerialNo is packed 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(  SELECT TOP 1 1 
                  FROM DELETED d
                  JOIN SerialNo sn (NOLOCK) ON sn.SerialNo = d.SerialNo
                  JOIN PackSerialNo psn (NOLOCK) ON psn.SerialNo = sn.serialno
               )    
      BEGIN
         SET @n_continue = 3
         SET @n_err = 68010
         SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Delete fail due to SerailNo is in Packing Progress or Packed'
                      + '. Unpack serial before unpick (ntrPickSerialNoDelete)'
      END
   END

   -- Check Pickdetail is shipped 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(  SELECT TOP 1 1 
                  FROM DELETED d
                  JOIN #TMP_SERIALDEL sn ON sn.SerialNo = d.SerialNo
                  JOIN PICKDETAIL pd WITH (NOLOCK) ON  pd.PickDetailKey = d.PickDetailKey
                  WHERE (pd.[Status] <= '5' OR pd.ShipFlag = 'P')
                  GROUP BY pd.PickDetailKey, pd.Qty
                  HAVING COUNT(1) > pd.Qty
               )    
      BEGIN
         SET @n_continue = 3
         SET @n_err  = 68020
         SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Deleted Serial Count is more than Picked Qty '
                      + '.(ntrPickSerialNoDelete)'
      END
   END

   -- Reverse SerialNo.Status
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @CUR_PSNO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT sn.SerialNoKey
      FROM DELETED D
      JOIN #TMP_SERIALDEL sn ON sn.SerialNo = d.SerialNo
      WHERE sn.PickStatus <= '5'
      ORDER BY sn.SerialNoKey 

      OPEN @CUR_PSNO 

      FETCH NEXT FROM @CUR_PSNO INTO @c_SerialNoKey
 
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE SerialNo WITH (ROWLOCK)
            SET [Status] = '1'  -- Received
             , Orderkey = ''   
             , OrderLineNumber = ''   
             , EditDate = GETDATE() 
             , EditWho = SUSER_SNAME()
         WHERE SerialNoKey = @c_SerialNoKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err   = 68030
            SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update SerialNo table fail (ntrPickSerialNoDelete)'
         END
         FETCH NEXT FROM @CUR_PSNO INTO @c_SerialNoKey
      END
      CLOSE @CUR_PSNO
      DEALLOCATE @CUR_PSNO
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @CUR_UPDPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT d.PickDetailKey
            ,sn.PickStatus
            ,Qty = COUNT(1)
            ,pd.Qty
      FROM DELETED D
      JOIN #TMP_SERIALDEL sn ON sn.SerialNo = d.SerialNo
      JOIN dbo.PICKDETAIl pd (NOLOCK) ON pd.PickDetailKey = sn.PickDetailKey
      WHERE sn.PickStatus < '5'
      AND   sn.PickDetailkey > ''
      GROUP BY d.PickDetailKey
            ,  sn.PickStatus
            ,  pd.Qty
      ORDER BY D.PickDetailKey 

      OPEN @CUR_UPDPD 

      FETCH NEXT FROM @CUR_UPDPD INTO @c_PickdetailKey, @c_PickStatus, @n_Qty, @n_Qty_PD
 
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK) 
            SET Qty      = CASE WHEN Qty - @n_Qty = 0 THEN Qty ELSE Qty - @n_Qty END
               ,[Status] = CASE WHEN Qty - @n_Qty = 0 THEN '0' ELSE [Status] END
          , EditDate = GETDATE() 
          , EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @c_PickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err   = 68040
            SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update PICKDETAIL table fail (ntrPickSerialNoDelete)'
         END

         IF @n_Continue = 1 AND  @n_Qty_PD - @n_Qty > 0
         BEGIN
            SET @c_NewPickDetailKey = ''
            SET @b_success = 1
            EXECUTE dbo.nspg_Getkey
               @KeyName       = 'PickDetailKey'
            ,  @fieldlength   =  10
            ,  @keystring     =  @c_NewPickDetailKey  OUTPUT
            ,  @b_Success     =  @b_success           OUTPUT
            ,  @n_err         =  @n_err               OUTPUT
            ,  @c_errmsg      =  @c_errmsg            OUTPUT
         
            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
            END  

            IF @n_Continue = 1
            BEGIN
               INSERT INTO PICKDETAIL
               (  PickDetailKey, PickHeaderKey, OrderKey,      OrderLineNumber 
               ,  Lot,           StorerKey,     Sku,           Qty 
               ,  Loc,           Id,            UOMQty,        UOM 
               ,  CaseID,        PackKey,       CartonGroup,   DoReplenish 
               ,  Replenishzone, docartonize,   Trafficcop,    PickMethod 
               ,  [Status],      PickSlipNo,    AddWho,        EditWho 
               ,  ShipFlag,      DropID,        TaskDetailKey, AltSKU 
               ,  ToLoc,         Notes,         MoveRefKey,    Channel_ID
               )
               SELECT   @c_NewPickDetailKey, PickHeaderKey,    OrderKey,      OrderLineNumber 
                      , LOT,                 StorerKey,        Sku,           @n_Qty 
                      , Loc,                 ID,               UOMQty,        UOM 
                      , CaseID,              PackKey,          CartonGroup,   DoReplenish 
                      , replenishzone,       docartonize,      Trafficcop,    PickMethod 
                      , '0',                 PickSlipNo,       SUSER_SNAME(), SUSER_SNAME() 
                      , ShipFlag,            DropID,           TaskDetailKey, AltSku 
                      , ToLoc,               Notes,            MoveRefKey,    Channel_ID
               FROM   PICKDETAIL (NOLOCK)
               WHERE  PickDetailKey = @c_PickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err   = 68040
                  SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update PICKDETAIL table fail (ntrPickSerialNoDelete)'
               END
            END
         END
         FETCH NEXT FROM @CUR_UPDPD INTO @c_PickdetailKey, @c_PickStatus, @n_Qty, @n_Qty_PD
      END
      CLOSE @CUR_UPDPD
      DEALLOCATE @CUR_UPDPD
   END

   IF @n_continue = 3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_success = 0      
      DECLARE @n_IsRDT INT      
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT      
      
      IF @n_IsRDT = 1      
      BEGIN      
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here      
         -- Instead we commit and raise an error back to parent, let the parent decide      
      
         -- Commit until the level we begin with      
         WHILE @@TRANCOUNT > @n_starttcnt      
            COMMIT TRAN      
      
         -- Raise error with severity = 10, instead of the default severity 16.      
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger      
         RAISERROR (@n_err, 10, 1) WITH SETERROR      
      
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten      
      END      
      ELSE      
      BEGIN      
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt      
         BEGIN      
            ROLLBACK TRAN      
         END      
         ELSE      
         BEGIN      
            WHILE @@TRANCOUNT > @n_starttcnt      
            BEGIN      
               COMMIT TRAN      
            END      
         END      
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPickSerialNoDelete'      
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
         RETURN      
      END      
   END      
   ELSE      
   BEGIN      
      SELECT @b_success = 1      
      WHILE @@TRANCOUNT > @n_starttcnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END
END

GO