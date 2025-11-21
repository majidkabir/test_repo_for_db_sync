SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_put_to_store_label_01_rdt                  */
/* Creation Date: 12-Nov-2018                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Wave Pickslip                                                */
/*                                                                       */
/* Called By: RDT - Fn593                                                */
/*            Datawidnow r_hk_put_to_store_label_01_rdt (WMS-6921)       */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 23/03/2022   ML       1.1  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_put_to_store_label_01_rdt] (
       @as_storerkey  NVARCHAR(10)
     , @as_dropid     NVARCHAR(20)
     , @as_palletid   NVARCHAR(3)
     , @as_username   NVARCHAR(128)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF OBJECT_ID('tempdb..#TEMP_PICKDETAIL') IS NOT NULL
      DROP TABLE #TEMP_PICKDETAIL

   DECLARE @cDataWidnow    NVARCHAR(40)
         , @n_StartTCnt    INT
         , @cPickdetailKey NVARCHAR(20)
         , @cDropID        NVARCHAR(20)
         , @cDropIDNew     NVARCHAR(20)

   SELECT @cDataWidnow = 'r_hk_put_to_store_label_01_rdt'
        , @n_StartTCnt  = @@TRANCOUNT

   CREATE TABLE #TEMP_PICKDETAIL (
        PickdetailKey    NVARCHAR(20)  NULL
      , DropID           NVARCHAR(20)  NULL
      , DropIDNew        NVARCHAR(20)  NULL
      , EditDate         DATETIME      NULL
      , EditWho          NVARCHAR(128) NULL
   )

   IF ISNULL(@as_palletid,'')<>''
   BEGIN
      SET @as_palletid = RIGHT('000' + ISNULL(LTRIM(RTRIM(@as_palletid)),''), 3)

      INSERT INTO #TEMP_PICKDETAIL(PickdetailKey, DropID, DropIDNew, EditDate, EditWho)
      SELECT Pickdetailkey = PD.Pickdetailkey
           , DropID        = PD.DropID
           , DropIDNew     = LTRIM(RTRIM(@as_palletid)) + RIGHT(LTRIM(RTRIM(ISNULL(OH.Userdefine09,''))),6) + ISNULL(LTRIM(RTRIM(PD.DropID)),'')
           , EditDate      = PD.EditDate
           , EditWho       = PD.EditWho
        FROM dbo.ORDERS     OH (NOLOCK)
        JOIN dbo.PICKDETAIL PD (NOLOCK) ON OH.OrderKey = PD.OrderKey
       WHERE OH.StorerKey = @as_storerkey
         AND PD.DropID = @as_dropid
         AND ISNULL(OH.Userdefine09,'')<>''
         AND ISNULL(PD.DropID,'')<>''
         AND ISNULL(OH.STATUS,'') = '3'
         AND ISNULL(PD.Status,'') < '5'
         AND PD.DropID LIKE 'ID%'
         AND LEN(PD.DropID)<=10
         AND @as_palletid NOT IN (
            SELECT DISTINCT LEFT(DropID,3)
              FROM dbo.ORDERS a(NOLOCK), dbo.PICKDETAIL b(NOLOCK)
             WHERE a.Orderkey  = b.Orderkey
               AND a.Storerkey = OH.Storerkey
               AND a.Userdefine09 <> OH.Userdefine09
               AND ISNULL(a.Userdefine09,'')<>''
               AND ISNULL(b.DropID,'')<>''
               AND b.DropID NOT LIKE 'ID%'
               AND b.Status<'5'
         )
       ORDER BY 1


     DECLARE C_PICKDETAIL CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT Pickdetailkey, DropID, DropIDNew
        FROM #TEMP_PICKDETAIL
       ORDER BY 1

      OPEN C_PICKDETAIL

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_PICKDETAIL
          INTO @cPickdetailKey, @cDropID, @cDropIDNew

         IF @@FETCH_STATUS<>0
            BREAK

         IF ISNULL(@cDropIDNew,'')<>''
         BEGIN
            UPDATE dbo.PICKDETAIL
               SET DropID = @cDropIDNew
                 , EditWho = CASE WHEN ISNULL(@as_username,'')<>'' THEN RTRIM(@as_username) ELSE SUSER_SNAME() END
                 , Trafficcop = NULL
             WHERE Storerkey = @as_storerkey
               AND PickdetailKey = @cPickdetailKey
               AND DropID = @cDropID
         END
      END

      CLOSE C_PICKDETAIL
      DEALLOCATE C_PICKDETAIL
   END


   SELECT Storerkey            = ISNULL( RTRIM( OH.StorerKey ), '' )
        , Wavekey              = ISNULL( RTRIM( OH.UserDefine09 ), '' )
        , Loc                  = ISNULL( RTRIM( UPPER(PD.Loc) ), '' )
        , Sku                  = ISNULL( RTRIM( PD.Sku ), '' )
        , Sku_Descr            = ISNULL( RTRIM( MAX(SKU.Descr) ), '')
        , DropID               = ISNULL( RTRIM( PD.DropID ), '')
        , ID                   = ISNULL( RTRIM( UPPER(PD.ID) ), '' )
        , Wave_Desc            = ISNULL( RTRIM( MAX( WAVE.Descr ) ), '' )
        , Wave_Userdefine01    = ISNULL( RTRIM( MAX( WAVE.UserDefine01 ) ), '' )
        , Qty                  = SUM(PD.Qty)
        , PD_AddDate           = MIN( CONVERT(DATETIME, CONVERT(CHAR(8), PD.AddDate, 112)) )
        , PD_EditDate          = MIN(ISNULL(PD2.EditDate, PD.EditDate))
        , PD_EditWho           = MIN(ISNULL(PD2.EditWho , PD.EditWho ))
        , Print_Date           = GETDATE()
        , Print_User           = ISNULL(@as_username, SUSER_SNAME())
        , Logo_Path            = MAX( RTRIM( ISNULL(RL.Notes, 'Logo_LFLogistics.png') ) )
        , Reprint              = MAX( CASE WHEN PD2.Pickdetailkey IS NULL THEN 'Y' ELSE 'N' END)
   FROM dbo.ORDERS        OH (NOLOCK)
   JOIN dbo.PICKDETAIL    PD (NOLOCK) ON OH.OrderKey = PD.OrderKey
   JOIN dbo.SKU          SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
   LEFT JOIN dbo.WAVE   WAVE (NOLOCK) ON OH.UserDefine09 = WAVE.WaveKey
   LEFT JOIN dbo.CODELKUP RL (NOLOCK) ON RL.Listname = 'RPTLOGO' AND RL.Code='LOGO' AND RL.Storerkey = OH.Storerkey AND RL.Long = @cDataWidnow
   LEFT JOIN #TEMP_PICKDETAIL PD2 ON PD.Pickdetailkey = PD2.Pickdetailkey

   WHERE OH.StorerKey = @as_storerkey
     AND PD.DropID = ISNULL(PD2.DropIDNew, @as_dropid)
     AND ISNULL(PD.DropID,'')<>''
     AND (ISNULL(OH.STATUS,'') = '3'
      OR (PD2.Pickdetailkey IS NULL AND (ISNULL(@as_palletid,'')='' OR ISNULL(@as_palletid,'')=LEFT(PD.DropID,3))) )

   GROUP BY OH.StorerKey
          , OH.UserDefine09
          , PD.Loc
          , PD.Sku
          , PD.ID
          , PD.DropID

   ORDER BY DropID
          , Sku

QUIT:
   WHILE @@TRANCOUNT > @n_StartTCnt
   BEGIN
      COMMIT TRAN
   END
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO