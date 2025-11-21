SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispWAVPK13                                         */  
/* Creation Date: 18-Nov-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15713 - PVH WAVGENPACKFROMPICKED                        */  
/*                                                                      */  
/* Called By: Wave                                                      */  
/*                                                                      */  
/* GitLab Version: 1.6                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2021-03-01   WLChooi  1.1  WMS-15713 - AssignPackLabelToOrdCfg (WL01)*/
/* 2021-03-04   WLChooi  1.2  WMS-16501 - Split Carton by Max LabelLine */
/*                                        using Storerconfig (WL02)     */
/* 2021-07-27   WLChooi  1.3  WMS-17575 - Limit Max Qty Per CTN (WL03)  */
/* 2021-08-11   WLChooi  1.4  Bug Fix for WMS-17575 (WL04)              */
/* 2022-02-07   WLChooi  1.5  DevOps Combine Script                     */
/* 2022-02-07   WLChooi  1.5  WMS-18862 - Limit Max SKU Per CTN (WL05)  */
/* 2022-02-22   WLChooi  1.6  JSM-53092 - Bug Fix (WL06)                */
/************************************************************************/  
  
CREATE PROC [dbo].[ispWAVPK13]  
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
           @c_Conso                        NVARCHAR(10) = 'N',
           @c_NewPickSlipNoGen             NVARCHAR(1) = 'N',
           @c_AllPickslipno                NVARCHAR(4000) = '',
           @c_GetPickslipno                NVARCHAR(10) = '',   --WL01
           @n_MaxLinePerCarton             INT,       --WL02
           @n_TTLCTN                       INT = 1,   --WL02
           @c_PrevSKU                      NVARCHAR(20),    --WL05
           @n_CountSKU                     INT = 0,         --WL05
           @n_MaxSKUPerCarton              INT = 0          --WL05
   
   --WL03 S
   DECLARE @n_CurrentQtyPerCtn             INT = 0
         , @n_PrevCartonNo                 INT = 0
         , @n_FirstCarton                  INT = 1

   CREATE TABLE #TMP_PS (
      SKU       NVARCHAR(20),
      Qty       INT,
      MAXQty    INT )
   
   CREATE TABLE #TMP_AssignCTN (
      SKU       NVARCHAR(20),
      Qty       INT,
      CartonNo  INT )
   --WL03 E
      
   DECLARE @n_Continue   INT,  
           @n_StartTCnt  INT,  
           @n_debug      INT  
  
   IF @n_err =  1  
      SET @n_debug = 1  
   ELSE  
      SET @n_debug = 0  
  
   SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_success = 1  
  
   --WL01 S
   CREATE TABLE #TMP_PSNO (
   	RowID        INT NOT NULL IDENTITY(1,1),
      Pickslipno   NVARCHAR(10)	
   )
   --WL01 E
   
   IF @@TRANCOUNT = 0  
      BEGIN TRAN  

   --WL02 S
   IF @n_continue IN(1,2)  
   BEGIN  
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.Wavekey = @c_Wavekey

      SELECT @n_MaxLinePerCarton = CASE WHEN ISNUMERIC(SC.OPTION2) = 1 THEN SC.OPTION2 ELSE 0 END   -- 0 as unlimited
           , @n_MaxSKUPerCarton  = CASE WHEN ISNUMERIC(SC.OPTION3) = 1 THEN SC.OPTION3 ELSE 0 END   -- 0 as unlimited   --WL05
      FROM Storerconfig SC (NOLOCK)
      WHERE SC.Storerkey = @c_Storerkey AND SC.Configkey = 'WAVGENPACKFROMPICKED_SP'
      
      IF ISNULL(@n_MaxLinePerCarton,0) = 0
         SET @n_MaxLinePerCarton = 99999   --WL05
      
      --WL05 S
      IF ISNULL(@n_MaxSKUPerCarton,0) = 0
         SET @n_MaxSKUPerCarton = 99999
      --WL05 E
   END 
   --WL02 E
    
   --Validation  
   IF @n_continue IN(1,2)  
   BEGIN  
      --IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK)  
      --          JOIN  WAVEDETAIL WD WITH (NOLOCK) ON PD.Orderkey = WD.Orderkey  
      --          WHERE PD.Status='4' AND PD.Qty > 0  
      --          AND  WD.Wavekey = @c_WaveKey)  
      --BEGIN  
      --   SELECT @n_continue = 3  
      --   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68010  
      --   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Short Pick with Qty > 0 (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      --   GOTO QUIT_SP  
      --END  
  
      --IF EXISTS(SELECT 1 FROM WAVEDETAIL WD (NOLOCK)  
      --          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
      --          WHERE WD.Wavekey = @c_Wavekey  
      --          AND O.Status <> '5')  
      --BEGIN  
      --   SELECT @n_continue = 3  
      --   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68020  
      --   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found some orders are not picked(5). (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      --   GOTO QUIT_SP  
      --END  
      
      IF EXISTS(SELECT 1 FROM WAVEDETAIL WD (NOLOCK)  
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                WHERE WD.Wavekey = @c_Wavekey  
                AND O.Salesman <> 'TRF')  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68030
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Only allow Transfer Orders - Orders.Salesman = ''TRF''. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         GOTO QUIT_SP  
      END  
  
      --IF NOT EXISTS(SELECT 1  
      --              FROM WAVE W (NOLOCK)  
      --              JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey  
      --              JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
      --              LEFT JOIN PACKHEADER PH (NOLOCK) ON WD.Orderkey = PH.Orderkey  
      --              WHERE W.Wavekey = @c_Wavekey  
      --              AND PH.Orderkey IS NULL)  
      --BEGIN  
      --   SELECT @n_continue = 3  
      --   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68040  
      --   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No pick record found to generate pack. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      --   GOTO QUIT_SP  
      --END  
   END 
   
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN   
      CREATE TABLE #TMP_DATA (
         Loadkey     NVARCHAR(10) NULL,
         Orderkey    NVARCHAR(10) NULL,
         Storerkey   NVARCHAR(15) NULL,
         Conso       NVARCHAR(1)  NULL 
      )
      
      --Discrete
      INSERT INTO #TMP_DATA (Loadkey, Orderkey, Storerkey, Conso) 
      SELECT O.LoadKey, WD.Orderkey, O.Storerkey, 'N'  
      FROM WAVE W (NOLOCK)  
      JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey  
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
      JOIN PICKHEADER PH (NOLOCK) ON WD.Orderkey = PH.Orderkey  
      --LEFT JOIN PackHeader PAH (NOLOCK) ON PAH.OrderKey = O.OrderKey
      WHERE W.Wavekey = @c_Wavekey 
      --AND PH.Orderkey = NULL
      UNION ALL
      SELECT O.LoadKey, WD.Orderkey, O.Storerkey, 'Y'  --Conso 
      FROM WAVE W (NOLOCK)  
      JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey  
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = O.OrderKey
      JOIN PICKHEADER PH (NOLOCK) ON LPD.Loadkey = PH.ExternOrderkey 
      --LEFT JOIN PackHeader PAH (NOLOCK) ON PAH.Loadkey = LPD.Loadkey
      WHERE W.Wavekey = @c_Wavekey
      --AND PH.LoadKey = NULL

      IF NOT EXISTS (SELECT 1 FROM #TMP_DATA)
      BEGIN
         GOTO QUIT_SP 
      END 
   END

   --Discrete
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN  
      DECLARE CUR_DISCPACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LoadKey, Orderkey, Storerkey  
         FROM #TMP_DATA 
         WHERE Conso = 'N'
         ORDER BY Loadkey, Orderkey
  
      OPEN CUR_DISCPACK  
  
      FETCH NEXT FROM CUR_DISCPACK INTO @c_Loadkey, @c_Orderkey, @c_Storerkey  
  
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN  
         SELECT @c_PickslipNo = PH.Pickheaderkey
         FROM PICKHEADER PH (NOLOCK)
         WHERE PH.OrderKey = @c_Orderkey
         
         IF ISNULL(@c_PickslipNo,'') = ''
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68045  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not Yet Generated Pickslipno for Orderkey#: ' + @c_Orderkey + ' (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
            GOTO QUIT_SP 
         END
         
         --Check if the pickslipno exists in Packheader
         IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_PickslipNo)
            GOTO NEXT_LOOP

         INSERT INTO PACKHEADER (PickSlipNo, StorerKey, [Route], OrderKey, OrderRefNo, Loadkey, Consigneekey, [Status], TTLCNTS, CtnTyp1, CtnCnt1, TotCtnCube, PackStatus)  
         SELECT @c_PickSlipNo, O.Storerkey, O.[Route], O.OrderKey, LEFT(O.ExternOrderKey, 18), O.LoadKey, O.ConsigneeKey, '0', 1, 'NORMAL', 1, ISNULL(CZ.[Cube],0), '0'
         FROM PICKHEADER PH (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON (PH.Orderkey = O.Orderkey)  
         JOIN STORER ST (NOLOCK) ON (ST.Storerkey = O.StorerKey)
         LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (CZ.CartonizationGroup = ST.CartonGroup AND CZ.UseSequence = 1)
         WHERE PH.PickHeaderKey = @c_PickSlipNo  

         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68050  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKHEADER Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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

         --WL03 S
         INSERT INTO #TMP_PS (SKU, Qty, MAXQty)
         SELECT P.SKU, SUM(P.Qty), @n_MaxLinePerCarton  
         FROM PICKDETAIL P (NOLOCK)  
         --JOIN LOADPLANDETAIL LPD (NOLOCK) ON P.OrderKey = LPD.OrderKey   --WL04  
         --WHERE LPD.LoadKey = @c_Loadkey   --WL04  
         WHERE P.OrderKey = @c_OrderKey   --WL04  
         AND P.Qty > 0  
         GROUP BY P.SKU;

         SET @n_CartonNo = 1
         SET @n_CurrentQtyPerCtn = 0
         SET @n_FirstCarton = 1
         
         DECLARE CUR_Carton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         WITH CTE AS (
               SELECT SKU, Qty, MAXQty,
                      (CASE WHEN Qty > MAXQty THEN MAXQty ELSE Qty END) AS NewSplitQty
               FROM #TMP_PS
               UNION ALL
               SELECT SKU, Qty, MAXQty,
                      (CASE WHEN Qty - MAXQty > MAXQty THEN MAXQty ELSE Qty - MAXQty END) AS NewSplitQty
               FROM #TMP_PS
               WHERE Qty - MAXQty > 0
             )
         SELECT SKU, NewSplitQty
         FROM CTE
         ORDER BY SKU, Qty
         
         OPEN CUR_Carton
         
         FETCH NEXT FROM CUR_Carton INTO @c_SKU, @n_Qty
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            --WL05 S
            IF ISNULL(@c_PrevSKU,'') <> @c_SKU
               SET @n_CountSKU = @n_CountSKU + 1
            --WL05 E

            IF @n_Qty = @n_MaxLinePerCarton AND @n_FirstCarton = 1
            BEGIN
               SET @n_CurrentQtyPerCtn = 0
            
               INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
               SELECT @c_SKU, @n_Qty, @n_CartonNo
            
               SET @n_CartonNo = @n_CartonNo + 1
               SET @n_CountSKU = 0   --WL05
            END
            ELSE IF @n_Qty = @n_MaxLinePerCarton
            BEGIN
               SET @n_CurrentQtyPerCtn = 0
               SET @n_CartonNo = @n_CartonNo + 1
            
               INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
               SELECT @c_SKU, @n_Qty, @n_CartonNo
            
               SET @n_CartonNo = @n_CartonNo + 1
               SET @n_CountSKU = 0   --WL05
            END
            ELSE
            BEGIN
               IF @n_CurrentQtyPerCtn + @n_Qty > @n_MaxLinePerCarton
               BEGIN
                  SET @n_CurrentQtyPerCtn = @n_Qty
                  SET @n_CartonNo = @n_CartonNo + 1
                  
                  INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
                  SELECT @c_SKU, @n_Qty, @n_CartonNo

                  SET @n_CountSKU = 1   --WL05   --WL06
               END
               ELSE
               BEGIN
                  --WL05 S
                  IF @n_CountSKU > @n_MaxSKUPerCarton
                  BEGIN
                     SET @n_CurrentQtyPerCtn = @n_Qty
                     SET @n_CartonNo = @n_CartonNo + 1
                     
                     INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
                     SELECT @c_SKU, @n_Qty, @n_CartonNo
                  
                     SET @n_CountSKU = 1   --WL05   --WL06
                  END   
                  ELSE
                  BEGIN
                     INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
                     SELECT @c_SKU, @n_Qty, @n_CartonNo
            
                     SET @n_CurrentQtyPerCtn = @n_CurrentQtyPerCtn + @n_Qty
                  END
                  --WL05 E
               END
            END

            SET @n_FirstCarton = 0
            SET @c_PrevSKU = @c_SKU   --WL05
            
            FETCH NEXT FROM CUR_Carton INTO @c_SKU, @n_Qty
         END
         CLOSE CUR_Carton
         DEALLOCATE CUR_Carton

         SET @n_PrevCartonNo = 0

         DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            --SELECT P.SKU, SUM(P.Qty)  
            --FROM PICKDETAIL P (NOLOCK)  
            --WHERE P.OrderKey = @c_OrderKey  
            --AND P.Qty > 0  
            --GROUP BY P.SKU  
            SELECT TAC.SKU, TAC.Qty, TAC.CartonNo 
            FROM #TMP_AssignCTN TAC
         --WL03 E
  
         OPEN CUR_PICKDETAIL  
  
         FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty, @n_CartonNo   --WL03 
  
         WHILE @@FETCH_STATUS<> -1  
         BEGIN  
            --WL03 S
         	--WL02 S
            --IF @n_LabelLineNo = @n_MaxLinePerCarton AND @n_MaxLinePerCarton > 0
            --BEGIN
            --   SET @c_LabelNo = ''  
            --   SET @n_CartonNo = @n_CartonNo + 1 
            --   SET @n_LabelLineNo = 0  
               
            --   EXEC isp_GenUCCLabelNo_Std  
            --      @cPickslipNo  = @c_Pickslipno,  
            --      @nCartonNo    = @n_CartonNo,  
            --      @cLabelNo     = @c_LabelNo OUTPUT,  
            --      @b_success    = @b_Success OUTPUT,  
            --      @n_err        = @n_err OUTPUT,  
            --      @c_errmsg     = @c_errmsg OUTPUT  
               
            --   IF @b_Success <> 1  
            --      SET @n_continue = 3  
            --END
            --WL02 E

            IF @n_PrevCartonNo = 0
               SET @n_PrevCartonNo = @n_CartonNo

            IF @n_PrevCartonNo <> @n_CartonNo
            BEGIN
               SET @c_LabelNo = ''
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
            END
            --WL03 E

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
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68060  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKDETAIL Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END 

            SET @n_PrevCartonNo = @n_CartonNo   --WL03

            FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty, @n_CartonNo   --WL03   
         END  
         CLOSE CUR_PICKDETAIL  
         DEALLOCATE CUR_PICKDETAIL  
         
         IF NOT EXISTS (SELECT 1    
                        FROM PICKINGINFO WITH (NOLOCK)    
                        WHERE PickSlipNo = @c_PickSlipNo    
         )    
         BEGIN    
            INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)    
            VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), NULL)    
    
            SET @n_err = @@ERROR 
               
            IF @n_err <> 0    
            BEGIN    
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68065 
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PICKINGINFO Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               GOTO QUIT_SP    
            END    
         END 
         
         UPDATE PICKINGINFO WITH (ROWLOCK)  
         SET ScanOutDate = GETDATE()  
         WHERE PickslipNo = @c_PickslipNo  
         AND (ScanOutDate IS NULL  
             OR ScanOutDate = '1900-01-01')  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68070  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PICKINGINFO Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END  
         
         --WL02 Comment
         --UPDATE PACKHEADER WITH (ROWLOCK)  
         --SET Status = '9'  
         --WHERE Pickslipno = @c_Pickslipno  
  
         --SET @n_err = @@ERROR  
  
         --IF @n_err <> 0  
         --BEGIN  
         --   SELECT @n_continue = 3  
         --   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68075  
         --   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PACKHEADER Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         --END  
         
         SET @c_NewPickSlipNoGen = 'Y'

         IF ISNULL(@c_Pickslipno,'') <> ''
         BEGIN
         	--WL01 S
            --IF @c_AllPickslipno = ''
            --BEGIN
            --   SET @c_AllPickslipno = @c_Pickslipno
            --END
            --ELSE
            --BEGIN
            --   SET @c_AllPickslipno = @c_AllPickslipno + ',' + @c_Pickslipno
            --END
            
            INSERT INTO #TMP_PSNO (Pickslipno)
            SELECT @c_Pickslipno
            --WL01 E
         END
NEXT_LOOP:
         TRUNCATE TABLE #TMP_PS   --WL04
         TRUNCATE TABLE #TMP_AssignCTN   --WL04
         FETCH NEXT FROM CUR_DISCPACK INTO @c_Loadkey, @c_Orderkey, @c_Storerkey 
      END  
      --CLOSE CUR_DISCPACK  
      --DEALLOCATE CUR_DISCPACK  
   END  
   
   --Conso
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN  
      DECLARE CUR_DISCPACKConso CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LoadKey, Storerkey  
         FROM #TMP_DATA 
         WHERE Conso = 'Y'
         ORDER BY Loadkey
  
      OPEN CUR_DISCPACKConso  
  
      FETCH NEXT FROM CUR_DISCPACKConso INTO @c_Loadkey, @c_Storerkey  
  
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN  
         SELECT @c_PickslipNo = PH.Pickheaderkey
         FROM PICKHEADER PH (NOLOCK)
         WHERE PH.ExternOrderkey = @c_Loadkey
         
         IF ISNULL(@c_PickslipNo,'') = ''
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68080  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not Yet Generated Pickslipno for Loadkey#: ' + @c_Loadkey + ' (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
            GOTO QUIT_SP 
         END
         
         --Check if the pickslipno exists in Packheader
         IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_PickslipNo)
            GOTO NEXT_ConsoLOOP
            
         INSERT INTO PACKHEADER (PickSlipNo, StorerKey, [Route], OrderKey, OrderRefNo, Loadkey, Consigneekey, [Status], TTLCNTS, CtnTyp1, CtnCnt1, TotCtnCube, PackStatus)  
         SELECT TOP 1 @c_PickSlipNo, O.Storerkey, '', '', '', O.LoadKey, '', '0', 1, 'NORMAL', 1, ISNULL(CZ.[Cube],0), '0'
         FROM PICKHEADER PH (NOLOCK)  
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON (LPD.LoadKey = PH.ExternOrderKey)
         JOIN ORDERS O (NOLOCK) ON (LPD.Orderkey = O.Orderkey)  
         JOIN STORER ST (NOLOCK) ON (ST.Storerkey = O.StorerKey)
         LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (CZ.CartonizationGroup = ST.CartonGroup AND CZ.UseSequence = 1)
         WHERE PH.PickHeaderKey = @c_PickSlipNo  

         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68050  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKHEADER Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
            
         --WL03 S
         INSERT INTO #TMP_PS (SKU, Qty, MAXQty)
         SELECT P.SKU, SUM(P.Qty), @n_MaxLinePerCarton  
         FROM PICKDETAIL P (NOLOCK)  
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON P.OrderKey = LPD.OrderKey
         WHERE LPD.LoadKey = @c_Loadkey
         AND P.Qty > 0  
         GROUP BY P.SKU;

         SET @n_CartonNo = 1
         SET @n_CurrentQtyPerCtn = 0
         SET @n_FirstCarton = 1
         
         DECLARE CUR_Carton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         WITH CTE AS (
               SELECT SKU, Qty, MAXQty,
                      (CASE WHEN Qty > MAXQty THEN MAXQty ELSE Qty END) AS NewSplitQty
               FROM #TMP_PS
               UNION ALL
               SELECT SKU, Qty, MAXQty,
                      (CASE WHEN Qty - MAXQty > MAXQty THEN MAXQty ELSE Qty - MAXQty END) AS NewSplitQty
               FROM #TMP_PS
               WHERE Qty - MAXQty > 0
             )
         SELECT SKU, NewSplitQty
         FROM CTE
         ORDER BY SKU, Qty
         
         OPEN CUR_Carton
         
         FETCH NEXT FROM CUR_Carton INTO @c_SKU, @n_Qty
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            --WL05 S
            IF ISNULL(@c_PrevSKU,'') <> @c_SKU
               SET @n_CountSKU = @n_CountSKU + 1
            --WL05 E

            IF @n_Qty = @n_MaxLinePerCarton AND @n_FirstCarton = 1
            BEGIN
               SET @n_CurrentQtyPerCtn = 0
            
               INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
               SELECT @c_SKU, @n_Qty, @n_CartonNo
            
               SET @n_CartonNo = @n_CartonNo + 1
               SET @n_CountSKU = 0   --WL05
            END
            ELSE IF @n_Qty = @n_MaxLinePerCarton
            BEGIN
               SET @n_CurrentQtyPerCtn = 0
               SET @n_CartonNo = @n_CartonNo + 1
            
               INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
               SELECT @c_SKU, @n_Qty, @n_CartonNo
            
               SET @n_CartonNo = @n_CartonNo + 1
               SET @n_CountSKU = 0   --WL05
            END
            ELSE
            BEGIN
               IF @n_CurrentQtyPerCtn + @n_Qty > @n_MaxLinePerCarton
               BEGIN
                  SET @n_CurrentQtyPerCtn = @n_Qty
                  SET @n_CartonNo = @n_CartonNo + 1
                  
                  INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
                  SELECT @c_SKU, @n_Qty, @n_CartonNo

                  SET @n_CountSKU = 1   --WL05   --WL06
               END
               ELSE
               BEGIN
                  --WL05 S
                  IF @n_CountSKU > @n_MaxSKUPerCarton
                  BEGIN
                     SET @n_CurrentQtyPerCtn = @n_Qty
                     SET @n_CartonNo = @n_CartonNo + 1
                     
                     INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
                     SELECT @c_SKU, @n_Qty, @n_CartonNo
                  
                     SET @n_CountSKU = 1   --WL05   --WL06
                  END   
                  ELSE
                  BEGIN
                     INSERT INTO #TMP_AssignCTN(SKU, Qty, CartonNo)
                     SELECT @c_SKU, @n_Qty, @n_CartonNo
            
                     SET @n_CurrentQtyPerCtn = @n_CurrentQtyPerCtn + @n_Qty
                  END
                  --WL05 E
               END
            END

            SET @n_FirstCarton = 0
            SET @c_PrevSKU = @c_SKU   --WL05
            
            FETCH NEXT FROM CUR_Carton INTO @c_SKU, @n_Qty
         END
         CLOSE CUR_Carton
         DEALLOCATE CUR_Carton
         
         SET @n_PrevCartonNo = 0

         DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            --SELECT P.SKU, SUM(P.Qty)  
            --FROM PICKDETAIL P (NOLOCK)  
            --JOIN LOADPLANDETAIL LPD (NOLOCK) ON P.OrderKey = LPD.OrderKey
            --WHERE LPD.LoadKey = @c_Loadkey
            --AND P.Qty > 0  
            --GROUP BY P.SKU  
            SELECT TAC.SKU, TAC.Qty, TAC.CartonNo 
            FROM #TMP_AssignCTN TAC
         --WL03 E
         OPEN CUR_PICKDETAIL  
  
         FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty, @n_CartonNo   --WL03  
  
         WHILE @@FETCH_STATUS<> -1  
         BEGIN  
            --WL03 S
         	--WL02 S
            --IF @n_LabelLineNo = @n_MaxLinePerCarton AND @n_MaxLinePerCarton > 0
            --BEGIN
            --   SET @c_LabelNo = ''  
            --   SET @n_CartonNo = @n_CartonNo + 1 
            --   SET @n_LabelLineNo = 0  
               
            --   EXEC isp_GenUCCLabelNo_Std  
            --      @cPickslipNo  = @c_Pickslipno,  
            --      @nCartonNo    = @n_CartonNo,  
            --      @cLabelNo     = @c_LabelNo OUTPUT,  
            --      @b_success    = @b_Success OUTPUT,  
            --      @n_err        = @n_err OUTPUT,  
            --      @c_errmsg     = @c_errmsg OUTPUT  
               
            --   IF @b_Success <> 1  
            --      SET @n_continue = 3  
            --END
            --WL02 E
            IF @n_PrevCartonNo = 0
               SET @n_PrevCartonNo = @n_CartonNo

            IF @n_PrevCartonNo <> @n_CartonNo
            BEGIN
               SET @c_LabelNo = ''
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
            END
            --WL03 E
            
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
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68085  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PACKDETAIL Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END  

            SET @n_PrevCartonNo = @n_CartonNo   --WL03

            FETCH NEXT FROM CUR_PICKDETAIL INTO @c_SKU, @n_Qty, @n_CartonNo   --WL03   
         END  
         CLOSE CUR_PICKDETAIL  
         DEALLOCATE CUR_PICKDETAIL  
         
         IF NOT EXISTS (SELECT 1    
                        FROM PICKINGINFO WITH (NOLOCK)    
                        WHERE PickSlipNo = @c_PickSlipNo    
         )    
         BEGIN    
            INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)    
            VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), NULL)    
    
            SET @n_err = @@ERROR 
               
            IF @n_err <> 0    
            BEGIN    
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68090 
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error On PICKINGINFO Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               GOTO QUIT_SP    
            END    
         END 
         
         UPDATE PICKINGINFO WITH (ROWLOCK)  
         SET ScanOutDate = GETDATE()  
         WHERE PickslipNo = @c_PickslipNo  
         AND (ScanOutDate IS NULL  
             OR ScanOutDate = '1900-01-01')  
  
         SET @n_err = @@ERROR  
  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68095 
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PICKINGINFO Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END  
         
         --WL02 Comment
         --UPDATE PACKHEADER WITH (ROWLOCK)  
         --SET Status = '9'  
         --WHERE Pickslipno = @c_Pickslipno  
  
         --SET @n_err = @@ERROR  
  
         --IF @n_err <> 0  
         --BEGIN  
         --   SELECT @n_continue = 3  
         --   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68100  
         --   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error On PACKHEADER Table. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         --END  

         IF ISNULL(@c_Pickslipno,'') <> ''
         BEGIN
         	--WL01 S
            --IF @c_AllPickslipno = ''
            --BEGIN
            --   SET @c_AllPickslipno = @c_Pickslipno
            --END
            --ELSE
            --BEGIN
            --   SET @c_AllPickslipno = @c_AllPickslipno + ',' + @c_Pickslipno
            --END
            
            INSERT INTO #TMP_PSNO (Pickslipno)
            SELECT @c_Pickslipno
            --WL01 E
         END
NEXT_ConsoLOOP:
         TRUNCATE TABLE #TMP_PS   --WL04
         TRUNCATE TABLE #TMP_AssignCTN   --WL04
         FETCH NEXT FROM CUR_DISCPACKConso INTO @c_Loadkey, @c_Storerkey 
      END  
      --CLOSE CUR_DISCPACKConso  
      --DEALLOCATE CUR_DISCPACKConso  
   END  
   
   --IF @n_Continue IN (1,2) AND ISNULL(@c_AllPickslipno,'') <> ''
   --BEGIN
   --   SELECT @c_Errmsg = 'Generate pack for Pickslipno ' + @c_AllPickslipno + ' is completed.'
   --END
   
   --WL01 S
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN  
   	DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	   SELECT DISTINCT Pickslipno
   	   FROM #TMP_PSNO
   	   ORDER BY Pickslipno
   	   
   	OPEN CUR_LOOP
   		
   	FETCH NEXT FROM CUR_LOOP INTO @c_GetPickslipno
   	
   	WHILE @@FETCH_STATUS <> -1
   	BEGIN
   		EXEC isp_AssignPackLabelToOrderByLoad
             @c_Pickslipno = @c_GetPickslipno
           , @b_Success    = @b_Success       OUTPUT
           , @n_err        = @n_err           OUTPUT
           , @c_errmsg     = @c_errmsg        OUTPUT
           
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68105  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Exec isp_AssignPackLabelToOrderByLoad. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO QUIT_SP
         END  
         
         --WL02 S
         SELECT @n_TTLCTN = MAX(CartonNo)
         FROM PACKDETAIL (NOLOCK)
         WHERE PickSlipNo = @c_GetPickslipno
         
         UPDATE PACKHEADER WITH (ROWLOCK) 
         SET TTLCNTS  = @n_TTLCTN, 
             [Status] = '9'  
         WHERE PickSlipNo = @c_GetPickslipno
         
         SELECT @n_err = @@ERROR
         
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68110
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Updating PACKHEADER. (ispWAVPK13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO QUIT_SP
         END  
         --WL02 E

   	   FETCH NEXT FROM CUR_LOOP INTO @c_GetPickslipno
   	END
   END
   --WL01 E
   
QUIT_SP:  
   IF CURSOR_STATUS('LOCAL', 'CUR_DISCPACK') IN (0 , 1)
   BEGIN
      CLOSE CUR_DISCPACK
      DEALLOCATE CUR_DISCPACK   
   END
   
   IF CURSOR_STATUS('LOCAL', 'CUR_DISCPACKConso') IN (0 , 1)
   BEGIN
      CLOSE CUR_DISCPACKConso
      DEALLOCATE CUR_DISCPACKConso   
   END
   
   IF OBJECT_ID('tempdb..#TMP_DATA') IS NOT NULL
      DROP TABLE #TMP_DATA
      
   --WL01 S
   IF OBJECT_ID('tempdb..#TMP_PSNO') IS NOT NULL
      DROP TABLE #TMP_PSNO
      
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   --WL01 E

   --WL03 S
   IF OBJECT_ID('tempdb..#TMP_PS') IS NOT NULL
      DROP TABLE #TMP_PS

   IF OBJECT_ID('tempdb..#TMP_AssignCTN') IS NOT NULL
      DROP TABLE #TMP_AssignCTN

   IF CURSOR_STATUS('LOCAL', 'CUR_Carton') IN (0 , 1)
   BEGIN
      CLOSE CUR_Carton
      DEALLOCATE CUR_Carton   
   END
   --WL03 E
   
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK13'      
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