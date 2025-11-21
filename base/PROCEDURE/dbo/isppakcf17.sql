SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF17                                            */
/* Creation Date: 12-Oct-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-18128 - [CN] APEDEMOD_Ecompacking_update_serialno_CR       */ 
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 12-Oct-2021  WLChooi 1.0   DevOps Combine Script                        */
/* 20-Oct-2021  WLChooi 1.1   WMS-18128 - Insert PackSerialNo Table (WL01) */
/***************************************************************************/  
CREATE PROC [dbo].[ispPAKCF17]  
(     @c_PickSlipNo  NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 
 
   DECLARE @C_Orderkey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_Sku             NVARCHAR(20)
         , @n_Qty             INT
         , @c_SerialNoKey     NVARCHAR(10)
         , @c_SQL             NVARCHAR(MAX)
         , @n_CartonNo        INT
         , @c_LabelLine       NVARCHAR(10)
         , @c_Orderkey1sttime NVARCHAR(10)
         , @c_DropID          NVARCHAR(20)
         , @c_LabelNo         NVARCHAR(20)   --WL01
         , @c_SerialNo        NVARCHAR(50)   --WL01
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   IF @@TRANCOUNT = 0
      BEGIN TRAN
   
   --For Normal Packing - Copy from ispPAKCF12
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN  
      SELECT PD.Storerkey, PD.Sku, PD.DropID, MAX(PD.CartonNo) AS CartonNo, MAX(PD.LabelLine) AS LabelLine     
      INTO #TMP_DROPID
      FROM PACKHEADER PH (NOLOCK) 
      JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
      WHERE PH.PickslipNo = @c_Pickslipno
      AND ISNULL(PD.DropID,'') <> ''
      GROUP BY PD.Storerkey, PD.Sku, PD.DropID
      
      DECLARE cur_ORDLINE_N CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku, SUM(PD.Qty) AS Qty
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey      
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku      
      JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
      WHERE PH.Pickslipno = @c_Pickslipno
      AND SKU.SerialNoCapture IN ('1','3')
      AND (EXISTS(SELECT 1 FROM SERIALNO SN (NOLOCK)
                 WHERE SN.Orderkey = O.Orderkey
                 AND SN.Storerkey = SKU.Storerkey
                 AND SN.Sku = SKU.Sku)
           OR EXISTS(SELECT 1 FROM #TMP_DROPID D
                 WHERE D.Storerkey = D.Storerkey
                 AND D.Sku = D.Sku)              
           )
      GROUP BY O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku
      ORDER BY OD.Sku, OD.OrderLineNumber
      
      OPEN cur_ORDLINE_N  
             
      FETCH NEXT FROM cur_ORDLINE_N INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @n_Qty
      
      IF @b_Debug = 1
      BEGIN
         SELECT  '@C_Orderkey=' + RTRIM(@C_Orderkey), '@c_OrderLineNumber='+RTRIM(@c_OrderLineNumber), 
                 '@c_Storerkey=' + RTRIM(@c_Storerkey), '@c_Sku=' + RTRIM(@c_Sku), 
                 '@n_Qty=' + CAST(@n_Qty AS NVARCHAR)
      END
      
      SET @c_Orderkey1sttime = @c_Orderkey
             
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN                        
         IF ISNULL(@c_Orderkey1sttime,'') <> ''
         BEGIN
            UPDATE SERIALNO WITH (ROWLOCK)
              SET Pickslipno = ''
                 ,CartonNo = 0
                 ,LabelLine = ''
                 ,TrafficCop = NULL
                 --,OrderLineNumber = ''
              WHERE (Orderkey = @c_Orderkey
              OR EXISTS(SELECT 1 FROM #TMP_DROPID
                        WHERE #TMP_DROPID.DropID = SERIALNO.Userdefine01
                       ) 
                     )   
              AND Storerkey = @c_Storerkey
         
            SET @n_Err = @@ERROR
                                
            IF @n_Err <> 0
            BEGIN
                SELECT @n_Continue = 3 
                SELECT @n_Err = 38010
                SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF17)'
            END                      
            
            SET @c_Orderkey1sttime = ''                      
         END
         
         --Serial no pack by UCC
             --Packdetail.dropid(stamp) and Serialno.userdefine01(interface) are UCC#
             --no stamping in serialno table when scanning.
             --1 carton 1 ucc#
         --Serial no pack by Sku (antidiversion)
             --stamp serialno.orderkey, status = '6' and orderlinenumumber = cartonno when scanning serial#
             --packdetail.dropid is empty
             --one carton one label line per sku        
         SET @c_SQL = ' 
             DECLARE cur_SERIALNO_N CURSOR FAST_FORWARD READ_ONLY FOR 
             SELECT TOP ' + RTRIM(CAST(@n_Qty AS NVARCHAR)) + ' SR.SerialNokey, ISNULL(TD.DropID,''''), 
                    CASE WHEN TD.DropID IS NULL THEN CAST(SR.OrderLineNumber AS INT) ELSE ISNULL(TD.CartonNo,0) END, 
                    ISNULL(TD.LabelLine,'''') 
             FROM SERIALNO SR (NOLOCK)                
             LEFT JOIN #TMP_DROPID TD ON SR.Userdefine01 = TD.DropID AND SR.Storerkey = TD.Storerkey AND SR.Sku = TD.Sku    
             WHERE (SR.Orderkey = @c_Orderkey OR TD.DropID IS NOT NULL)                                    
             AND SR.Storerkey = @c_Storerkey 
             AND SR.Sku = @c_Sku
             AND SR.Pickslipno = ''''
             ORDER BY SR.Userdefine01, SR.SerialNokey '
      
         EXEC sp_executesql @c_SQL,
            N'@c_Orderkey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20)', 
            @c_Orderkey,
            @c_Storerkey,
            @c_Sku
                     
         IF @b_Debug = 1
            PRINT @c_SQL         
      
         OPEN cur_SERIALNO_N  
      
         FETCH NEXT FROM cur_SERIALNO_N INTO @c_SerialNoKey, @c_DropID, @n_CartonNo, @c_LabelLine
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
              IF @b_Debug = 1
             BEGIN
                SELECT  '@c_SerialNoKey=' + RTRIM(@c_SerialNoKey) + ' @c_Dropid=' + RTRIM(@c_DropID) + ' @n_cartonno=' + RTRIM(CAST(@c_DropID AS NVARCHAR)) + ' @c_LabelLine=' + RTRIM(@c_LabelLine) 
             END
             
             IF ISNULL(@c_DropId,'') = ''
             BEGIN
                 SELECT TOP 1 @c_LabelLine = PD.LabelLine
                 FROM PACKDETAIL PD (NOLOCK)
                 WHERE PD.Pickslipno = @c_Pickslipno
                 AND PD.Storerkey = @c_Storerkey
                 AND PD.Sku = @c_Sku
                 AND PD.CartonNo = @n_CartonNo
             END
      
              UPDATE SERIALNO WITH (ROWLOCK)
              SET Orderkey = @c_Orderkey
                 ,OrderLineNumber = @c_OrderLineNumber
                 ,Pickslipno = @c_Pickslipno
                 ,CartonNo = @n_CartonNo
                 ,Labelline = @c_LabelLine
                 ,Status = '6'
                 ,TrafficCop = NULL
              WHERE SerialNokey = @c_SerialNokey
      
            SET @n_Err = @@ERROR
                                
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3 
               SELECT @n_Err = 38020
               SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF17)'
            END                                                 
              
            FETCH NEXT FROM cur_SERIALNO_N INTO @c_SerialNoKey, @c_DropID, @n_CartonNo, @c_LabelLine
         END
         CLOSE cur_SERIALNO_N
         DEALLOCATE cur_SERIALNO_N                              
          
         FETCH NEXT FROM cur_ORDLINE_N INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @n_Qty    
      END
      CLOSE cur_ORDLINE_N
      DEALLOCATE cur_ORDLINE_N
   END
   
   --For ECOM Packing
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN                      
      DECLARE cur_ORDLINE_E CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku, SUM(PD.Qty) AS Qty
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey      
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku      
      JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
                                 AND OD.SKU = PD.SKU
      WHERE PH.Pickslipno = @c_Pickslipno
      AND SKU.SerialNoCapture IN ('1','3')
      AND EXISTS(SELECT 1 FROM SERIALNO SN (NOLOCK)
                 JOIN PackSerialNo PSN (NOLOCK) ON SN.SerialNo = PSN.SerialNo AND SN.StorerKey = PSN.StorerKey 
                                               AND SN.SKU = PSN.SKU
                 WHERE SN.Storerkey = SKU.Storerkey
                 AND SN.Sku = SKU.Sku AND PSN.PickSlipNo = PH.PickSlipNo)
      GROUP BY O.Orderkey, OD.OrderLineNumber, OD.Storerkey, OD.Sku
      ORDER BY OD.Sku, OD.OrderLineNumber
      
      OPEN cur_ORDLINE_E  
             
      FETCH NEXT FROM cur_ORDLINE_E INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @n_Qty
             
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN    
         IF @b_Debug = 1
         BEGIN
            SELECT  '@c_Orderkey=' + RTRIM(@C_Orderkey), '@c_OrderLineNumber='+RTRIM(@c_OrderLineNumber), 
                    '@c_Storerkey=' + RTRIM(@c_Storerkey), '@c_Sku=' + RTRIM(@c_Sku), '@n_CartonNo=' + RTRIM(@n_CartonNo), 
                    '@n_Qty=' + CAST(@n_Qty AS NVARCHAR)
         END
                          
         SET @c_SQL = ' 
             DECLARE cur_SERIALNO_E CURSOR FAST_FORWARD READ_ONLY FOR 
             SELECT TOP ' + RTRIM(CAST(@n_Qty AS NVARCHAR)) + ' SN.SerialNokey
             FROM SERIALNO SN (NOLOCK)
             JOIN PackSerialNo PSN (NOLOCK) ON SN.SerialNo = PSN.SerialNo AND SN.StorerKey = PSN.StorerKey 
                                           AND SN.SKU = PSN.SKU
             WHERE PSN.Pickslipno = @c_PickSlipNo
             AND SN.Storerkey = @c_Storerkey
             AND SN.Sku = @c_Sku
             AND SN.Orderkey = '''' AND SN.OrderLineNumber = '''' AND SN.Pickslipno = ''''
             ORDER BY SN.SerialNokey '
      
         EXEC sp_executesql @c_SQL,
            N'@c_PickSlipNo NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20)',
            @c_PickSlipNo,
            @c_Storerkey,
            @c_Sku
            
         IF @b_Debug = 1
            PRINT @c_SQL         
             
         OPEN cur_SERIALNO_E  
      
         FETCH NEXT FROM cur_SERIALNO_E INTO @c_SerialNoKey
         
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN
            IF @b_Debug = 1
            BEGIN
               SELECT '@c_SerialNoKey=' + RTRIM(@c_SerialNoKey) 
            END
      
            UPDATE SERIALNO WITH (ROWLOCK)
            SET Orderkey        = @c_Orderkey
              , OrderLineNumber = @c_OrderLineNumber
              , Pickslipno      = @c_Pickslipno
              , [Status]        = '6'
              , TrafficCop      = NULL
              , EditDate        = GETDATE()
              , EditWho         = SUSER_SNAME()
            WHERE SerialNokey = @c_SerialNokey
      
            SET @n_Err = @@ERROR
                                
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3 
               SELECT @n_Err = 38030
               SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF17)'
            END                                                 
              
            FETCH NEXT FROM cur_SERIALNO_E INTO @c_SerialNoKey
         END
         CLOSE cur_SERIALNO_E
         DEALLOCATE cur_SERIALNO_E                              
          
         FETCH NEXT FROM cur_ORDLINE_E INTO @C_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @n_Qty
      END
      CLOSE cur_ORDLINE_E
      DEALLOCATE cur_ORDLINE_E

      --Update CartonNo & LabelLine
      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         DECLARE cur_CartonNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.Pickslipno, PD.SKU, PD.CartonNo, 
                (SELECT SUM(PAD.Qty) FROM PACKDETAIL PAD (NOLOCK) WHERE PAD.PickSlipNo = PD.Pickslipno AND PAD.CartonNo = PD.CartonNo AND PAD.SKU = PD.SKU) AS Qty
         FROM PACKDETAIL PD (NOLOCK)
         JOIN PackSerialNo PSN (NOLOCK) ON PD.PickSlipNo = PSN.PickSlipNo AND PD.CartonNo = PSN.CartonNo 
                                       AND PD.LabelNo = PSN.LabelNo AND PD.LabelLine = PSN.LabelLine
         WHERE PD.Pickslipno = @c_Pickslipno
         GROUP BY PD.Pickslipno, PD.SKU, PD.CartonNo
         ORDER BY PD.SKU, PD.CartonNo
         
         OPEN cur_CartonNo  
             
         FETCH NEXT FROM cur_CartonNo INTO @c_Pickslipno, @c_Sku, @n_CartonNo, @n_Qty
             
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN              
            SET @c_SQL = ' 
                DECLARE cur_SERIALNO_C CURSOR FAST_FORWARD READ_ONLY FOR 
                SELECT TOP ' + RTRIM(CAST(@n_Qty AS NVARCHAR)) + ' SN.SerialNokey
                FROM SERIALNO SN (NOLOCK)
                JOIN PackSerialNo PSN (NOLOCK) ON SN.SerialNo = PSN.SerialNo AND SN.StorerKey = PSN.StorerKey 
                                              AND SN.SKU = PSN.SKU
                WHERE PSN.Pickslipno = @c_PickSlipNo
                AND SN.Storerkey = @c_Storerkey
                AND SN.Sku = @c_Sku
                AND PSN.CartonNo = @n_CartonNo
                ORDER BY SN.SerialNokey '
      
            EXEC sp_executesql @c_SQL,
               N'@c_PickSlipNo NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @n_CartonNo NVARCHAR(10)', 
               @c_PickSlipNo,
               @c_Storerkey,
               @c_Sku,
               @n_CartonNo
            
            IF @b_Debug = 1
               PRINT @c_SQL         
             
            OPEN cur_SERIALNO_C  
      
            FETCH NEXT FROM cur_SERIALNO_C INTO @c_SerialNoKey
         
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  SELECT '@c_SerialNoKey=' + RTRIM(@c_SerialNoKey) 
               END
      
               SELECT TOP 1 @c_LabelLine = PD.LabelLine
               FROM PACKDETAIL PD (NOLOCK)
               WHERE PD.Pickslipno = @c_Pickslipno
               AND PD.Sku = @c_Sku
               AND PD.CartonNo = @n_CartonNo
      
               UPDATE SERIALNO WITH (ROWLOCK)
               SET CartonNo      = @n_CartonNo
                 , LabelLine     = @c_LabelLine
                 , TrafficCop    = NULL
                 , EditDate      = GETDATE()
                 , EditWho       = SUSER_SNAME()
               WHERE SerialNokey = @c_SerialNokey
      
               SET @n_Err = @@ERROR
                                
               IF @n_Err <> 0
               BEGIN
                  SELECT @n_Continue = 3 
                  SELECT @n_Err = 38040
                  SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update SERIALNO Table Failed. (ispPAKCF17)'
               END                                                 
              
               FETCH NEXT FROM cur_SERIALNO_C INTO @c_SerialNoKey
            END
            CLOSE cur_SERIALNO_C
            DEALLOCATE cur_SERIALNO_C                              
          
            FETCH NEXT FROM cur_CartonNo INTO @c_Pickslipno, @c_Sku, @n_CartonNo, @n_Qty
         END
         CLOSE cur_CartonNo
         DEALLOCATE cur_CartonNo
      END
   END

   --WL01 S
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_PSN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickSlipNo, PD.CartonNo, PD.LabelNo, PD.LabelLine, PD.StorerKey, PD.SKU, 1 AS Qty, SN.SerialNo
      FROM PACKDETAIL PD (NOLOCK)
      JOIN SerialNo SN (NOLOCK) ON SN.PickSlipNo = PD.PickSlipNo AND SN.CartonNo = PD.CartonNo AND SN.LabelLine = PD.LabelLine
                               AND SN.SKU = PD.SKU AND SN.StorerKey = PD.StorerKey
      WHERE PD.PickSlipNo = @c_PickSlipNo
      ORDER BY PD.CartonNo, PD.LabelLine, PD.SKU

      OPEN CUR_PSN  
             
      FETCH NEXT FROM CUR_PSN INTO @c_Pickslipno, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_Storerkey, @c_Sku, @n_Qty, @c_SerialNo
             
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN
         IF NOT EXISTS (SELECT 1 
                        FROM PackSerialNo PSN (NOLOCK) 
                        WHERE PSN.PickSlipNo = @c_Pickslipno
                          AND PSN.CartonNo   = @n_CartonNo
                          AND PSN.LabelNo    = @c_LabelNo
                          AND PSN.LabelLine  = @c_LabelLine
                          AND PSN.StorerKey  = @c_Storerkey
                          AND PSN.SKU        = @c_Sku
                          AND PSN.SerialNo   = @c_SerialNo)
         BEGIN
            INSERT INTO PackSerialNo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY, ArchiveCop)
            SELECT @c_Pickslipno, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_Storerkey, @c_Sku, @c_SerialNo, @n_Qty, '9'

            SET @n_Err = @@ERROR
                                
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3 
               SELECT @n_Err = 38045
               SELECT @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert PACKSERIALNO Table Failed. (ispPAKCF17)'
            END  
         END

         FETCH NEXT FROM CUR_PSN INTO @c_Pickslipno, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_Storerkey, @c_Sku, @n_Qty, @c_SerialNo
      END
      CLOSE CUR_PSN
      DEALLOCATE CUR_PSN
   END
   --WL01 E

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'cur_ORDLINE_N') IN (0 , 1)
   BEGIN
      CLOSE cur_ORDLINE_N
      DEALLOCATE cur_ORDLINE_N  
   END

   IF CURSOR_STATUS('LOCAL', 'cur_ORDLINE_E') IN (0 , 1)
   BEGIN
      CLOSE cur_ORDLINE_E
      DEALLOCATE cur_ORDLINE_E   
   END

   IF CURSOR_STATUS('LOCAL', 'cur_SERIALNO_N') IN (0 , 1)
   BEGIN
      CLOSE cur_SERIALNO_N
      DEALLOCATE cur_SERIALNO_N   
   END

   IF CURSOR_STATUS('LOCAL', 'cur_SERIALNO_E') IN (0 , 1)
   BEGIN
      CLOSE cur_SERIALNO_E
      DEALLOCATE cur_SERIALNO_E   
   END

   IF CURSOR_STATUS('LOCAL', 'cur_SERIALNO_C') IN (0 , 1)
   BEGIN
      CLOSE cur_SERIALNO_C
      DEALLOCATE cur_SERIALNO_C   
   END
   
   IF CURSOR_STATUS('LOCAL', 'cur_CartonNo') IN (0 , 1)
   BEGIN
      CLOSE cur_CartonNo
      DEALLOCATE cur_CartonNo   
   END

   --WL01 S
   IF OBJECT_ID('tempdb..#TMP_DROPID') IS NOT NULL
      DROP TABLE #TMP_DROPID

   IF CURSOR_STATUS('LOCAL', 'CUR_PSN') IN (0 , 1)
   BEGIN
      CLOSE CUR_PSN
      DEALLOCATE CUR_PSN   
   END
   --WL01 E
   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF17'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO