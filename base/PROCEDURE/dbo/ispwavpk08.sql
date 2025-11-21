SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispWAVPK08                                         */  
/* Creation Date: 18-APR-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-8583 HK Loreal Wave generate packing                    */  
/*                                                                      */  
/* Called By: Wave                                                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 21-Jun-2019  ML       1.0  Fix by Michael Lam                        */
/************************************************************************/  
  
CREATE PROC [dbo].[ispWAVPK08]  
   @c_Wavekey   NVARCHAR(10),  
   @b_Success   INT      OUTPUT,  
   @n_Err       INT      OUTPUT,  
   @c_ErrMsg    NVARCHAR(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_Storerkey                    NVARCHAR(15),  
           @c_Sku                          NVARCHAR(20),  
           @n_Qty                          INT,  
           @c_PickslipNo                   NVARCHAR(10),  
           @n_CartonNo                     INT,  
           @c_LabelNo                      NVARCHAR(20),  
           @n_LabelLineNo                  INT,  
           @c_LabelLineNo                  NVARCHAR(5),  
           @c_Orderkey                     NVARCHAR(10),  
           @c_Loadkey                      NVARCHAR(10),  
           @c_Conso                        NVARCHAR(10)  
  
   DECLARE @n_Continue   INT,  
           @n_StartTCnt  INT,  
           @n_debug      INT  
  
   IF @n_err =  1  
      SET @n_debug = 1  
   ELSE  
      SET @n_debug = 0  
  
   SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_success = 1  
  
   IF @@TRANCOUNT = 0  
      BEGIN TRAN  
  
   --Validation  
   IF @n_continue IN(1,2)  
   BEGIN  
      IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK)  
                JOIN  WAVEDETAIL WD WITH (NOLOCK) ON PD.Orderkey = WD.Orderkey  
                WHERE PD.Status='4' AND PD.Qty > 0  
                AND  WD.Wavekey = @c_WaveKey)  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Short Pick with Qty > 0 (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         GOTO QUIT_SP  
      END  
  
      IF EXISTS(SELECT 1 FROM WAVEDETAIL WD (NOLOCK)  
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                WHERE WD.Wavekey = @c_Wavekey  
                AND O.Status <> '5')  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38015  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found some orders are not picked(5). (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         GOTO QUIT_SP  
      END  
      IF EXISTS(SELECT 1  
                FROM WAVEDETAIL WD (NOLOCK)  
                JOIN LOADPLANDETAIL LPD (NOLOCK) ON WD.Orderkey = LPD.Orderkey  
                JOIN PICKHEADER PH (NOLOCK) ON LPD.Loadkey = PH.ExternOrderKey AND ISNULL(PH.Orderkey,'') = '' -- ML  
                WHERE WD.Wavekey = @c_Wavekey)  
         SET @c_Conso = 'Y'  
      ELSE  
         SET @c_Conso = 'N'  
  
      IF @c_Conso = 'Y'  
      BEGIN  
         IF EXISTS(SELECT 1  
                   FROM WAVEDETAIL WD (NOLOCK)  
-- ML                   LEFT JOIN LOADPLANDETAIL LPD (NOLOCK) ON WD.Orderkey = LPD.Orderkey  
-- ML                   WHERE WD.Wavekey = @c_Wavekey  
-- ML                   AND LPD.Orderkey IS NULL)  
                   JOIN PICKHEADER PH (NOLOCK) ON WD.Orderkey = PH.Orderkey -- ML  
                   WHERE WD.Wavekey = @c_Wavekey)                           -- ML  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The wave is not allowed to mix discrete and conso orders. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO QUIT_SP  
         END  
      END  
  
      IF @c_Conso = 'N'  
      BEGIN  
         IF NOT EXISTS(SELECT 1  
                       FROM WAVE W (NOLOCK)  
                       JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey  
                       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                       LEFT JOIN PACKHEADER PH (NOLOCK) ON WD.Orderkey = PH.Orderkey  
                       WHERE W.Wavekey = @c_Wavekey  
                       AND PH.Orderkey IS NULL)  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38030  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No pick record found to generate pack. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO QUIT_SP  
         END  
      END  
  
      IF @c_Conso = 'Y'  
      BEGIN  
         IF NOT EXISTS(SELECT 1  
                       FROM WAVE W (NOLOCK)  
                       JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey  
                       JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                       JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey  
                       LEFT JOIN PACKHEADER PH (NOLOCK) ON LPD.Loadkey = PH.Loadkey AND (PH.Orderkey IS NULL OR PH.Orderkey = '')  
                       WHERE W.Wavekey = @c_Wavekey  
                       AND PH.Loadkey IS NULL)  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38040  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No pick record found to generate pack. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO QUIT_SP  
         END  
      END  
  
   END  
  
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_Conso = 'N'  
   BEGIN  
      DECLARE CUR_DISCPACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT WD.Orderkey, O.Storerkey  
         FROM WAVE W (NOLOCK)  
         JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey  
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
         LEFT JOIN PACKHEADER PH (NOLOCK) ON WD.Orderkey = PH.Orderkey  
         WHERE W.Wavekey = @c_Wavekey  
         AND PH.Orderkey IS NULL  
  
      OPEN CUR_DISCPACK  
  
      FETCH NEXT FROM CUR_DISCPACK INTO @c_Orderkey, @c_Storerkey  
  
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN  
        EXEC isp_CreatePickSlip  
             @c_Orderkey             = @c_Orderkey  
            ,@c_Loadkey              = ''  
            ,@c_Wavekey              = ''  
-- ML           ,@c_PickslipType         = ''  
            ,@c_PickslipType         = '8'            -- ML  
            ,@c_ConsolidateByLoad    = 'N'  
            ,@c_Refkeylookup         = 'N'  
            ,@c_LinkPickSlipToPick   = 'N'  
            ,@c_AutoScanIn           = 'Y'  
            ,@b_Success              = @b_Success OUTPUT  
      ,@n_Err                  = @n_Err     OUTPUT  
            ,@c_ErrMsg               = @c_ErrMsg  OUTPUT  
  
         IF @b_Success <> 1  
            SET @n_continue = 3  
  
         SELECT TOP 1 @c_PickslipNo = PH.Pickheaderkey  
         FROM PICKHEADER PH (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey  
         WHERE O.Orderkey = @c_Orderkey  
  
         INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)  
         SELECT O.Route, O.OrderKey, LEFT(O.ExternOrderKey, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @c_PickSlipNo  
         FROM  PICKHEADER PH (NOLOCK)  
         JOIN  ORDERS O (NOLOCK) ON (PH.Orderkey = O.Orderkey)  
         WHERE PH.PickHeaderKey = @c_PickSlipNo  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38050  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKHEADER Table. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END  
  
         SET @c_LabelNo = ''  
         SET @n_CartonNo = 1  
         SET @n_LabelLineNo = 0  
  
         EXEC isp_GenUCCLabelNo_Std  
            @cPickslipNo  = @c_Pickslipno,  
            @nCartonNo    = @n_CartonNo,  
            @cLabelNo     = @c_LabelNo OUTPUT,  
            @b_success    = @b_Success OUTPUT,  
            @n_err        = @n_err OUTPUT,  
            @c_errmsg     = @c_errmsg OUTPUT  
  
         IF @b_Success <> 1  
            SET @n_continue = 3  
  
  
         DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT P.SKU, SUM(P.Qty)  
            FROM PICKDETAIL P (NOLOCK)  
            WHERE P.OrderKey = @c_OrderKey  
            AND P.Qty > 0  
            GROUP BY P.SKU  
  
         OPEN CUR_PICKDETAIL  
  
         FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty  
  
         WHILE @@FETCH_STATUS<>-1  
         BEGIN  
            SET @n_LabelLineNo = @n_LabelLineNo + 1  
            SET @c_LabelLineNo = RIGHT('00000' + RTRIM(CAST(@n_LabelLineNo AS NVARCHAR)),5)  
  
            INSERT INTO PACKDETAIL  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)  
            VALUES  
               (@c_PickSlipNo, @n_CartonNo, @c_LabelNo, @c_LabelLineNo, @c_StorerKey, @c_SKU,  
                @n_Qty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())  
  
            SET @n_err = @@ERROR  
  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38060  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKDETAIL Table. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END  
  
            FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty  
         END  
         CLOSE CUR_PICKDETAIL  
         DEALLOCATE CUR_PICKDETAIL  
  
         UPDATE PICKINGINFO WITH (ROWLOCK)  
         SET ScanOutDate = GETDATE()  
         WHERE PickslipNo = @c_PickslipNo  
         AND (ScanOutDate IS NULL  
             OR ScanOutDate = '1900-01-01')  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38070  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PICKINGINFO Table. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END  
  
         UPDATE PACKHEADER WITH (ROWLOCK)  
         SET Status = '9'  
         WHERE Pickslipno = @c_Pickslipno  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38080  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PACKHEADER Table. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END  
  
         FETCH NEXT FROM CUR_DISCPACK INTO @c_Orderkey, @c_Storerkey  
      END  
      CLOSE CUR_DISCPACK  
      DEALLOCATE CUR_DISCPACK  
   END  
  
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_Conso = 'Y'  
   BEGIN  
      DECLARE CUR_CONSOCPACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT LPD.Loadkey, O.Storerkey  
         FROM WAVE W (NOLOCK)  
         JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey  
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey  
         LEFT JOIN PACKHEADER PH (NOLOCK) ON LPD.Loadkey = PH.Loadkey AND (PH.Orderkey IS NULL OR PH.Orderkey = '')  
         WHERE W.Wavekey = @c_Wavekey  
         AND PH.Loadkey IS NULL  
  
      OPEN CUR_CONSOCPACK  
  
      FETCH NEXT FROM CUR_CONSOCPACK INTO @c_Loadkey, @c_Storerkey  
  
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN  
        EXEC isp_CreatePickSlip  
             @c_Orderkey             = ''  
            ,@c_Loadkey              = @c_Loadkey  
            ,@c_Wavekey              = ''  
-- ML            ,@c_PickslipType         = 'LB'  
            ,@c_PickslipType         = '9'                -- ML  
            ,@c_ConsolidateByLoad    = 'Y'  
-- ML            ,@c_Refkeylookup         = 'Y'  
            ,@c_Refkeylookup         = 'N'                -- ML  
            ,@c_LinkPickSlipToPick   = 'N'  
            ,@c_AutoScanIn           = 'Y'  
            ,@b_Success              = @b_Success OUTPUT  
            ,@n_Err                  = @n_Err     OUTPUT  
            ,@c_ErrMsg               = @c_ErrMsg  OUTPUT  
  
         IF @b_Success <> 1  
            SET @n_continue = 3  
  
         SELECT TOP 1 @c_PickslipNo = PH.Pickheaderkey  
         FROM PICKHEADER PH (NOLOCK)  
         JOIN LOADPLAN LP (NOLOCK) ON PH.ExternOrderkey = LP.Loadkey  
         WHERE LP.Loadkey = @c_Loadkey  
         AND (PH.Orderkey IS NULL OR PH.Orderkey = '')  
  
         INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)  
         SELECT TOP 1 O.Route, '', '', LPD.LoadKey, '',O.Storerkey, @c_PickSlipNo  
         FROM  PICKHEADER PH (NOLOCK)  
         JOIN  LOADPLANDETAIL LPD (NOLOCK) ON PH.ExternOrderkey = LPD.Loadkey  
         JOIN  ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey  
         WHERE PH.PickHeaderKey = @c_PickSlipNo  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38090  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKHEADER Table. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END  
  
         SET @c_LabelNo = ''  
         SET @n_CartonNo = 1  
         SET @n_LabelLineNo = 0  
  
         EXEC isp_GenUCCLabelNo_Std  
            @cPickslipNo  = @c_Pickslipno,  
            @nCartonNo    = @n_CartonNo,  
            @cLabelNo     = @c_LabelNo OUTPUT,  
            @b_success    = @b_Success OUTPUT,  
            @n_err        = @n_err OUTPUT,  
            @c_errmsg     = @c_errmsg OUTPUT  
  
         IF @b_Success <> 1  
            SET @n_continue = 3  
  
         DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT P.SKU, SUM(P.Qty)  
            FROM PICKDETAIL P (NOLOCK)  
            JOIN LOADPLANDETAIL LPD (NOLOCK) ON P.Orderkey = LPD.Orderkey  
            WHERE LPD.Loadkey = @c_Loadkey  
            AND P.Qty > 0  
            GROUP BY P.SKU  
  
         OPEN CUR_PICKDETAIL  
  
         FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty  
  
         WHILE @@FETCH_STATUS<>-1  
         BEGIN  
            SET @n_LabelLineNo = @n_LabelLineNo + 1  
            SET @c_LabelLineNo = RIGHT('00000' + RTRIM(CAST(@n_LabelLineNo AS NVARCHAR)),5)  
  
            INSERT INTO PACKDETAIL  
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)  
            VALUES  
               (@c_PickSlipNo, @n_CartonNo, @c_LabelNo, @c_LabelLineNo, @c_StorerKey, @c_SKU,  
                @n_Qty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())  
  
            SET @n_err = @@ERROR  
  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38100  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKDETAIL Table. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END  
  
            FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty  
         END  
         CLOSE CUR_PICKDETAIL  
         DEALLOCATE CUR_PICKDETAIL  
  
         UPDATE PICKINGINFO WITH (ROWLOCK)  
         SET ScanOutDate = GETDATE()  
         WHERE PickslipNo = @c_PickslipNo  
         AND (ScanOutDate IS NULL  
             OR ScanOutDate = '1900-01-01')  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38110  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PICKINGINFO Table. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END  
  
         UPDATE PACKHEADER WITH (ROWLOCK)  
         SET Status = '9'  
         WHERE Pickslipno = @c_Pickslipno  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38120  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PACKHEADER Table. (ispWAVPK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END  
  
         FETCH NEXT FROM CUR_CONSOCPACK INTO @c_Orderkey, @c_Storerkey  
      END  
      CLOSE CUR_CONSOCPACK  
      DEALLOCATE CUR_CONSOCPACK  
   END  
  
   QUIT_SP:  
  
  IF @n_Continue=3  -- Error Occured - Process AND Return  
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
   EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK08'  
   RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   --RAISERROR @nErr @cErrmsg  
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
END  

GO