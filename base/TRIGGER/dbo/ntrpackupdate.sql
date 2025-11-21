SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/
/* Trigger: ntrPackUpdate                                                        */
/* Creation Date:                                                                */
/* Copyright: IDS                                                                */
/* Written by:                                                                   */
/*                                                                               */
/* Purpose:  Update other transactions while PACK line is to be updated.         */
/*                                                                               */
/* Return Status:                                                                */
/*                                                                               */
/* Usage:                                                                        */
/*                                                                               */
/* Called By: When records Updated                                               */
/*                                                                               */
/* PVCS Version: 1.1                                                             */
/*                                                                               */
/* Version: 5.4                                                                  */
/*                                                                               */
/* Modifications:                                                                */
/* Date         Author   		Ver. Purposes                                      */
/* 14-Jun-2007  YokeBeen 		1.0  FBR#78500 - CBM Outbound - (YokeBeen01)       */
/*                       		     Trigger records into TransmitLog when update  */
/*                       		     on fields - LengthUOM3/WidthUOM3/HeightUOM3.  */
/*                       		     - SQL2005 Changes.                            */
/* 27-Jun-2008  Shong    		1.1  Performance Tuning                            */
/* 17-Mar-2009  TLTING   		1.2  Change user_name() to SUSER_SNAME()           */
/* 22-May-2012  TLTING01 		1.3  DM integrity - add update editdate B4         */
/*                       		     TrafficCop check                              */
/* 29-Mar-2012  NJOW01   		1.4  SOS#244886 - Calculate cube by multi-uom      */
/*	01-Jun-2012  GTGOH    		1.5  SOS#236126 - Add new field for PACKLOG(GOH01) */
/* 28-Oct-2013  TLTING   		1.6  Review Editdate column update                 */
/* 21-Jul-2017  TLTING   		1.7  SET Option                                    */
/* 07-Aug-2019  WLChooi  		1.8  WMS-9809 - Update SKU table from Pack (WL01)  */
/* 09-Sep-2020  WLChooi  		1.9  WMS-15120 - Update SKU table from Pack for CN */
/*                       		     (WL02)                                        */
/* 02-Oct-2020  TLTING02 		1.10 EXCEPT replace UPDATE() -actual value changed */
/* 04-Mar-2022  TLTING   		1.11 WMS-19029 prevent bulk update or delete       */
/* 2022-04-12   kelvinongcy	1.12 amend way for control user run batch (kocy01)	*/ 
/*********************************************************************************/
  
CREATE   TRIGGER [dbo].[ntrPackUpdate]  
ON  [dbo].[PACK]  
FOR UPDATE  
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
   DECLARE @b_Success INT          -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err INT              -- Error number returned by stored procedure or this trigger  
         , @n_err2 INT             -- For Additional Error Detection  
         , @c_errmsg NVARCHAR(250)     -- Error message returned by stored procedure or this trigger  
         , @n_continue INT                   
         , @n_starttcnt INT        -- Holds the current transaction count  
         , @c_preprocess NVARCHAR(250) -- preprocess  
         , @c_pstprocess NVARCHAR(250) -- post process  
         , @n_cnt INT                
         , @c_Country    NVARCHAR(10) = ''  --WL01  
         , @c_authority  NVARCHAR(1)  = ''  --WL01             , @C_TEST NVARCHAR(100)    
  
   -- (YokeBeen01) - Start  
   DECLARE @c_Storerkey NVARCHAR(15)   
         , @c_Sku NVARCHAR(20)   
         , @c_PackKey NVARCHAR(10)   
         , @c_authority_owitf NVARCHAR(1)    
         , @c_transmitlogkey NVARCHAR(10)   
  
   SELECT  @c_Storerkey  = ''   
         , @c_Sku        = ''  
         , @c_PackKey    = ''  
         , @c_authority_owitf = ''    
   -- (YokeBeen01) - End  
  
   --WL01 Start  
   SELECT @c_Country = LTRIM(RTRIM(NSQLValue))  
   FROM NSQLConfig (NOLOCK)   
   WHERE Configkey = 'Country'  
   --WL01 End  
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
  
   IF UPDATE(ArchiveCop)  
   BEGIN  
      SELECT @n_continue = 4   
   END  
     
   /* START -- Added by YokeBeen -- 17th-July-2001 */  
   IF ( @n_continue = 1 OR @n_continue = 2 )  AND NOT UPDATE(EditDate)  
   BEGIN  
      UPDATE PACK WITH (ROWLOCK)  
      SET EditDate = GETDATE(),  
          EditWho = SUSER_SNAME(),  
          TrafficCop = NULL  
      FROM PACK, INSERTED
      WHERE PACK.PackKey = INSERTED.PackKey  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85803   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))  
                         +': Update Failed On Table PACK. (ntrPackUpdate)' + ' ( '   
                         +' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
      END  
   END  
  
   --IF ( (SELECT COUNT(1) FROM   INSERTED  ) > 100 ) 
   --    AND SUSER_SNAME() NOT IN ( 'itadmin', 'alpha\wmsadmingt', 'ALPHA\SRVwmsadminlfl', 'ALPHA\SRVwmsadmincn', 'iml'    )
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
        AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67408   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table PACK. Batch Update not allow! (ntrPackUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END
  
   /* END Added */  
     
   IF UPDATE(TrafficCop)  
   BEGIN  
      SELECT @n_continue = 4   
   END  
  
   -- (YokeBeen01) - Start  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      -- Retrieve related info from INSERTED table into a cursor for TransmitLog Insertion   
       DECLARE C_TransmitLogUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT SKU.Storerkey,   
              SKU.SKU,   
              INSERTED.Packkey    
         FROM INSERTED   
         JOIN SKU WITH (NOLOCK) ON (INSERTED.Packkey = SKU.Packkey)  
         JOIN STORERCONFIG WITH (NOLOCK) ON (STORERCONFIG.StorerKey = SKU.StorerKey   
                                             AND STORERCONFIG.sValue = '1'  
                                             AND STORERCONFIG.ConfigKey = 'OWITF')  
  
     
      OPEN C_TransmitLogUpdate  
      FETCH NEXT FROM C_TransmitLogUpdate INTO @c_Storerkey, @c_Sku, @c_PackKey    
  
      WHILE @@FETCH_STATUS <> -1   
      BEGIN  
         -- Check if Pack info was updated  
         IF EXISTS ( SELECT 1 FROM INSERTED   
                     JOIN DELETED   ON (INSERTED.Packkey = DELETED.Packkey)   
                     WHERE INSERTED.Packkey = @c_PackKey AND (INSERTED.LengthUOM3 <> DELETED.LengthUOM3 OR   
                                                              INSERTED.WidthUOM3  <> DELETED.WidthUOM3 OR   
                                                              INSERTED.HeightUOM3 <> DELETED.HeightUOM3) )  
         BEGIN  
            IF NOT EXISTS ( SELECT 1 FROM TRANSMITLOG WITH (NOLOCK) WHERE Key1 = @c_PackKey   
                            AND Key2 = @c_Storerkey AND Key3 = @c_Sku AND TransmitFlag = '0' )   
            BEGIN   
               SELECT @c_transmitlogkey = ''  
               SELECT @b_success = 1  
  
               EXECUTE nspg_getkey  
                  'TransmitlogKey'  
                  , 10  
                  , @c_transmitlogkey OUTPUT  
                  , @b_success OUTPUT  
                  , @n_err OUTPUT  
                  , @c_errmsg OUTPUT   
  
               IF NOT @b_success=1  
               BEGIN  
                  SELECT @n_continue = 3 , @n_err = 85801  
                  SELECT @c_errmsg = 'ntrPackUpdate: ' + ISNULL(dbo.fnc_RTrim(@c_errmsg),'')   
               END  
  
               IF ( @n_continue = 1 OR @n_continue = 2 )   
               BEGIN  
                  INSERT TRANSMITLOG (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)   
                  VALUES ( @c_transmitlogkey, 'OWCBM', @c_PackKey, @c_Storerkey, @c_Sku, 0 )  
  
                  SELECT @n_err = @@Error  
                  IF NOT @n_err = 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 85802  
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+  
                                      ': Insert Into TransmitLog Table (OWCBM) Failed (ntrPackUpdate)' +   
                                      ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
                  END   
               END   
            END -- (Outstanding TransmitLog record not exists)   
         END -- Packkey Exists  
  
         FETCH NEXT FROM C_TransmitLogUpdate INTO @c_Storerkey, @c_Sku, @c_PackKey   
      END -- WHILE @@FETCH_STATUS <> -1   
      CLOSE C_TransmitLogUpdate  
      DEALLOCATE C_TransmitLogUpdate   
   END -- @n_continue = 1 OR @n_continue = 2  
   -- (YokeBeen01) - End  
  
   /* #INCLUDE <TRPU_1.SQL> */    
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      --TLTING02  
      IF EXISTS (  
           SELECT PackUOM1, Casecnt, PackUOM2, InnerPack, PackUOM3, Qty, PackUOM4, Pallet, LengthUOM1, WidthUOM1,   
           HeightUOM1, CubeUOM1  FROM inserted  
           EXCEPT  
           SELECT PackUOM1, Casecnt, PackUOM2, InnerPack, PackUOM3, Qty, PackUOM4, Pallet, LengthUOM1, WidthUOM1,   
           HeightUOM1, CubeUOM1 FROM deleted  
          )   
       BEGIN   
         INSERT INTO PACKLOG ( PackKey, PackDescr  
                        , OldPackUOM1, OldCaseCnt, PackUOM1, CaseCnt  
                        , OLDPackUOM2, OLDInnerPack, PackUOM2, InnerPack  
                        , OLDPackUOM3, OLDQty, PackUOM3, Qty  
                        , OLDPackUOM4, OLDPallet, PackUOM4, Pallet  
                        , EditDate, EditWho  
                        , OLDLengthUOM1, LengthUOM1, OLDWidththUOM1, WidthUOM1  
                        , OLDHeightUOM1, HeightUOM1, OLDCubeUOM1, CubeUOM1   
                         )  
         SELECT INSERTED.Packkey, INSERTED.PackDescr,   
                DELETED.PackUOM1, DELETED.Casecnt,   INSERTED.PackUOM1, INSERTED.Casecnt,  
                DELETED.PackUOM2, DELETED.InnerPack, INSERTED.PackUOM2, INSERTED.InnerPack,   
                DELETED.PackUOM3, DELETED.Qty,       INSERTED.PackUOM3, INSERTED.Qty,   
                DELETED.PackUOM4, DELETED.Pallet,    INSERTED.PackUOM4, INSERTED.Pallet,   
                GETDATE(), SUSER_SNAME()   
               ,DELETED.LengthUOM1, INSERTED.LengthUOM1, DELETED.WidthUOM1, INSERTED.WidthUOM1,   
                DELETED.HeightUOM1, INSERTED.HeightUOM1, DELETED.CubeUOM1,   
					dbo.fnc_CalculateCube(INSERTED.LengthUOM1, INSERTED.WidthUOM1, INSERTED.HeightUOM1,'','','')   
           FROM INSERTED   
           JOIN DELETED ON (INSERTED.PACKKEY = DELETED.PACKKEY)  
      END  
  
      --TLTING02  
      IF EXISTS (  
           SELECT LengthUOM1, WidthUOM1, HeightUOM1, LengthUOM2, WidthUOM2, HeightUOM2,  LengthUOM3, WidthUOM3, HeightUOM3  
           , LengthUOM4, WidthUOM4, HeightUOM4 FROM inserted  
           EXCEPT  
           SELECT LengthUOM1, WidthUOM1, HeightUOM1, LengthUOM2, WidthUOM2, HeightUOM2,  LengthUOM3, WidthUOM3, HeightUOM3  
           , LengthUOM4, WidthUOM4, HeightUOM4 FROM deleted  
          )   
            
   /*   IF UPDATE(LengthUOM1) OR UPDATE(WidthUOM1) OR UPDATE(HeightUOM1) OR  
         UPDATE(LengthUOM2) OR UPDATE(WidthUOM2) OR UPDATE(HeightUOM2) OR  
         UPDATE(LengthUOM3) OR UPDATE(WidthUOM3) OR UPDATE(HeightUOM3) OR  
         UPDATE(LengthUOM4) OR UPDATE(WidthUOM4) OR UPDATE(HeightUOM4) */  
      BEGIN   
         UPDATE PACK SET  
                PACK.CubeUOM1 = dbo.fnc_CalculateCube(INSERTED.LengthUOM1, INSERTED.WidthUOM1, INSERTED.HeightUOM1,'','',''),  --NJOW01  
                PACK.CubeUOM2 = dbo.fnc_CalculateCube(INSERTED.LengthUOM2, INSERTED.WidthUOM2, INSERTED.HeightUOM2,'','',''),  --NJOW01  
                PACK.CubeUOM3 = dbo.fnc_CalculateCube(INSERTED.LengthUOM3, INSERTED.WidthUOM3, INSERTED.HeightUOM3,'','',''),  --NJOW01  
                PACK.CubeUOM4 = dbo.fnc_CalculateCube(INSERTED.LengthUOM4, INSERTED.WidthUOM4, INSERTED.HeightUOM4,'','','')   --NJOW01  
           FROM PACK WITH (NOLOCK)   
           JOIN INSERTED ON (PACK.PACKKEY = INSERTED.PACKKEY)  
      END   
   END  
  
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
   IF @n_err <> 0  
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))  
                      +': Update Failed On Table PACK. (ntrPackUpdate)' + ' ( ' + ' SQLSvr MESSAGE='   
                      + ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)),'') + ' ) '  
   END  
  
   --WL01 Start  
   --IF (@n_continue = 1 OR @n_continue = 2) AND @c_Country = 'SG'   --WL02  
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_Country IN ('SG','CN')   --WL02  
   BEGIN  
      --TLTING02  
      IF EXISTS (  
           SELECT GrossWgt, NetWgt, LengthUOM3, WidthUOM3, HeightUOM3, LengthUOM1, WidthUOM1, HeightUOM1, CubeUOM3, CubeUOM1   
           FROM inserted  
           EXCEPT  
           SELECT GrossWgt, NetWgt, LengthUOM3, WidthUOM3, HeightUOM3, LengthUOM1, WidthUOM1, HeightUOM1, CubeUOM3, CubeUOM1  
           FROM deleted  
          )   
  /*    IF UPDATE(GrossWgt) OR UPDATE(NetWgt) OR  
         UPDATE(LengthUOM3) OR UPDATE(WidthUOM3) OR UPDATE(HeightUOM3) OR  
         UPDATE(LengthUOM1) OR UPDATE(WidthUOM1) OR UPDATE(HeightUOM1) OR  
         UPDATE(CubeUOM3) OR UPDATE(CubeUOM1)*/  
      BEGIN  
         DECLARE cur_UpdateSKUFromPack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT SKU.StorerKey, SKU.SKU, SKU.PACKKey  
         FROM INSERTED  
         JOIN SKU (NOLOCK) ON (SKU.PACKKey = INSERTED.PackKey)  
  
         OPEN cur_UpdateSKUFromPack  
  
         FETCH NEXT FROM cur_UpdateSKUFromPack INTO @c_Storerkey, @c_SKU, @c_PACKKey  
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN   
               EXEC nspGetRight     
               ''                   -- facility    
            ,  @c_Storerkey         -- Storerkey    
            ,  NULL                 -- Sku    
            ,  'UpdateSKUFromPack'   -- Configkey    
            ,  @b_Success           OUTPUT     
            ,  @c_authority         OUTPUT     
            ,  @n_Err               OUTPUT     
            ,  @c_ErrMsg            OUTPUT   
              
            IF @b_success <> 1    
            BEGIN    
               SET @n_continue = 3    
               SET @n_err = 85803     
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (ntrPackUpdate)'     
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '      
            END  
              
            --WL02 START  
            IF @c_authority = 1 AND @c_Country = 'SG'   --WL02   
            BEGIN  
               UPDATE SKU WITH (ROWLOCK)  
               SET SKU.StdGrossWgt = INSERTED.GrossWgt,  
                   SKU.StdCube     = CAST(((INSERTED.LengthUOM3 * INSERTED.WidthUOM3 * INSERTED.HeightUOM3) / 1000000) AS DECIMAL(30,6)),  
                   SKU.GrossWgt    = INSERTED.NetWgt,  
                   SKU.[Cube]      = CAST(((INSERTED.LengthUOM1 * INSERTED.WidthUOM1 * INSERTED.HeightUOM1) / 1000000) AS DECIMAL(30,6))  
               FROM SKU  
               JOIN INSERTED ON (INSERTED.Packkey = SKU.Packkey)  
               WHERE SKU.StorerKey = @c_Storerkey AND SKU.SKU = @c_SKU AND SKU.PACKKey = @c_PACKKey  
            END  
            ELSE IF @c_authority = 1 AND @c_Country = 'CN'  
            BEGIN  
               UPDATE SKU WITH (ROWLOCK)  
               SET SKU.StdGrossWgt = INSERTED.GrossWgt,  
                   SKU.StdCube     = (CAST(((INSERTED.LengthUOM1 * INSERTED.WidthUOM1 * INSERTED.HeightUOM1) / 1000000) AS DECIMAL(30,6)) / INSERTED.Casecnt),  
                   SKU.GrossWgt    = INSERTED.NetWgt,  
                   SKU.[Cube]      = CAST(((INSERTED.LengthUOM1 * INSERTED.WidthUOM1 * INSERTED.HeightUOM1) / 1000000) AS DECIMAL(30,6)),  
                   SKU.Measurement = NULL  
               FROM SKU  
               JOIN INSERTED ON (INSERTED.Packkey = SKU.Packkey)  
               WHERE SKU.StorerKey = @c_Storerkey AND SKU.SKU = @c_SKU AND SKU.PACKKey = @c_PACKKey AND SKU.Measurement = 'new'  
            END  
            --WL02 END  
            FETCH NEXT FROM cur_UpdateSKUFromPack INTO @c_Storerkey, @c_SKU, @c_PACKKey  
         END  
         CLOSE cur_UpdateSKUFromPack  
         DEALLOCATE cur_UpdateSKUFromPack  
      END  
   END  
   --WL01 End  
QUIT_SP:  
   /* #INCLUDE <TRPU_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
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
  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPackUpdate'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END
   
END --Main

GO