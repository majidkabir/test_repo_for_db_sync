SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_DropIDSN01                                          */
/* Creation Date: 22-MAY-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By: isp_SerialNo_dropid_Wrapper                               */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 04-JUL-2017 Wan01    1.1   WMS-2332 - Changes to Logitech Packing    */
/* 04-JUL-2017 Wan02    1.2   WMS-3062 - CN&SG Logitech Packing         */
/* 27-Nov-2017 TLTING   1.2   Performance tune                          */
/* 12-MAR-2020 Wan03    1.3   WMS-13254 - [CN]Logitech_Tote ID          */
/*                            Packing_pallet serialno_CR                */
/************************************************************************/
CREATE PROC [dbo].[isp_DropIDSN01]
           @c_PickSlipNo      NVARCHAR(10) 
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_DropId          NVARCHAR(20)
         , @c_SerialNo        NVARCHAR(30)
         , @n_Qty             INT            OUTPUT
         , @b_DisableQty      INT            OUTPUT
         , @c_PackMode        NVARCHAR(50)
         , @c_Source          NVARCHAR(50)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         
         , @c_SerialNoType    NVARCHAR(1)
         , @n_Pallet          FLOAT = 0      --(Wan03)
         , @n_CaseCnt         FLOAT
         , @n_InnerPack       FLOAT

         , @n_CtnPerPL        INT = 0        --(Wan03)
         , @n_PLQty           INT = 0        --(Wan03)
         , @n_QtyAllocated    INT = 0        --(Wan03)
         , @n_QtyPacked       INT = 0        --(Wan03)

         , @n_POS             INT            --(Wan02)
         , @c_Char            CHAR(1)        --(Wan02)

         , @c_BUSR7           NVARCHAR(30)=''--(Wan03)
         , @c_Wavekey         NVARCHAR(10)=''--(Wan03)

   DECLARE @SCANSERIAL TABLE                                   --(Wan03)
         (  SerialNo NVARCHAR(30) NOT NULL PRIMARY KEY         --(Wan03)
         ,  Qty      INT          NOT NULL DEFAULT(0)          --(Wan03)
         )
   
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   --(Wan03) - START
   IF @c_Source in ('serialno', 'qty')
   BEGIN
      SET @c_SerialNo = ISNULL(@c_SerialNo,'')
      SET @c_SerialNoType = RIGHT(RTRIM(@c_SerialNo),1)         
      IF @c_SerialNoType IN ('P')      
      BEGIN
         SET @n_CaseCnt = 0
         SELECT @n_CaseCnt = P.CaseCnt
               ,@n_Pallet  = P.Pallet
               ,@c_BUSR7   = ISNULL(RTRIM(S.BUSR7),'')
         FROM SKU S WITH (NOLOCK)
         JOIN PACK P WITH (NOLOCK) ON S.Packkey = P.Packkey
         WHERE S.Storerkey = @c_Storerkey
         AND S.Sku = @c_Sku

         IF @c_BUSR7 = 'Yes'
         BEGIN
            INSERT INTO @SCANSERIAL (   SerialNo, Qty   )
            SELECT TID.TrackingID
                  ,TID.Qty
            FROM TRACKINGID TID WITH (NOLOCK)
            WHERE TID.ParentTrackingID = @c_SerialNo
            AND   TID.Storerkey = @c_Storerkey
            AND   TID.PickMethod<>'loose'                   --2020-07-02
            AND   TID.[Status] >= 1 AND TID.[Status] <= 9   --2020-07-20
       
            SET @n_CtnPerPL = @@ROWCOUNT

            SET @n_PLQty = @n_CaseCnt * @n_CtnPerPL

            --SELECT @n_PLQty = ISNULL(SUM(Qty),0)
            --FROM @SCANSERIAL
         END
      END
      ELSE
      BEGIN
         INSERT INTO @SCANSERIAL (   SerialNo   )
         VALUES (@c_SerialNo)
      END 
   END 
   --(Wan03) - END

   IF @c_Source = 'serialno' AND @c_SerialNo <> ''
   BEGIN
      --(Wan01) - START
      IF LEN(@c_SerialNo) <> 12 
      BEGIN 
         SET @n_Continue = 3
         SET @n_err = 60005                                                                                          
         SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Invalid Serial # Length: ' 
                      + RTRIM(@c_SerialNo) + '. (isp_DropIDSN01)' 
         GOTO QUIT_SP
      END
      --(Wan01) - END

      --(Wan02) - START
      SET @c_SerialNo = UPPER(@c_SerialNo) 
      SET @n_POS = 1
      WHILE @n_POS <= LEN(@c_SerialNo)
      BEGIN
         SET @c_Char = SUBSTRING(@c_SerialNo, @n_POS, 1)

         IF  (ASCII(@c_Char) NOT BETWEEN 48 AND 57)           --0 - 9
         AND (ASCII(@c_Char) NOT BETWEEN 65 AND 90)           --A - Z
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 60006                                                                                          
            SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Serial # Contain Special Character: ' 
                         + RTRIM(@c_SerialNo) + '. Please Scan Again. (isp_DropIDSN01)' 
            GOTO QUIT_SP
         END

         IF @n_POS IN (5,6)
         BEGIN
            IF ASCII(@c_Char) NOT BETWEEN 65 AND 90         --A - Z
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 60007                                                                                         
               SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Serial # Contains Invalid Character at position 5 & 6: ' 
                            + RTRIM(@c_SerialNo) + '. Please Scan Again. (isp_DropIDSN01)' 
               GOTO QUIT_SP
            END
         END

         --(Wan03) - START
         IF @n_POS IN (1,2,3,4) AND @c_SerialNoType = 'P'
         BEGIN
            IF ASCII(@c_Char) NOT BETWEEN 48 AND 57         --0 - 9
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 60008                                                                                         
               SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Serial # Contain Invalid Character at position 1 - 4: ' 
                            + RTRIM(@c_SerialNo) + '. Please Scan Again. (isp_DropIDSN01)' 
               GOTO QUIT_SP
            END
         END
         --(Wan03) - END

         SET @n_POS = @n_POS + 1
      END
      --(Wan02) - END   
      
      IF @c_SerialNoType IN ('P')      
      BEGIN
         IF NOT EXISTS (SELECT 1 
                        FROM @SCANSERIAL
                       )
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 60040                                                                                         
            SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Invalid Pallet Serial#:' 
                         + RTRIM(@c_SerialNo) + '. (isp_DropIDSN01)' 
            GOTO QUIT_SP
         END               

         IF @n_PLQty > @n_Pallet AND @n_Pallet > 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 60050                                                                                          
            SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Pallet Count Qty > Sku''s Pallet setup in PACK table. Serial#:' 
                         + RTRIM(@c_SerialNo) + '. (isp_DropIDSN01)' 
            GOTO QUIT_SP            
         END

         --2020-07-29 - start 
         --IF EXISTS ( SELECT 1 
         --            FROM @SCANSERIAL SS
         --            LEFT JOIN MASTERSERIALNO MS WITH (NOLOCK) ON  SS.SerialNo  = MS.ParentSerialNo
         --                                                      AND MS.Storerkey = @c_Storerkey
         --                                                      AND MS.Sku       = @c_Sku
         --            WHERE MS.MasterSerialNoKey IS NULL
         --            )
         --BEGIN
         --   SET @n_Continue = 3
         --   SET @n_err = 60060                                                                                          
         --   SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Invalid Carton Serial# Of Pallet found. Serial #:' 
         --                + RTRIM(@c_SerialNo) + '. (isp_DropIDSN01)' 
         --   GOTO QUIT_SP
         --END 
         --2020-07-29 - end              
      END
      --(Wan03) - END

      IF EXISTS ( SELECT 1
                  FROM @SCANSERIAL SS                                                                          --(Wan03)
                  JOIN SERIALNO WITH (NOLOCK) ON SERIALNO.SerialNo = SS.SerialNo                               --(Wan03)
                  JOIN fnc_GetWaveOrder_DropID (@c_DropId) TOTEORD ON (SERIALNO.Orderkey = TOTEORD.Orderkey)
                  --WHERE SERIALNO.SerialNo = @c_SerialNo                                                      --(Wan03)
                  WHERE SERIALNO.Storerkey = @c_Storerkey  --tlting                                            --(Wan03)
                  AND SERIALNO.ExternStatus <> 'CANC'
               )
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 60010                                                                                           
         SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Duplicate Serial #: ' 
                      + RTRIM(@c_SerialNo) + '. (isp_DropIDSN01)' 
         GOTO QUIT_SP
      END

      --(Wan02) - START
      IF EXISTS ( SELECT 1
                  FROM @SCANSERIAL SS                                                                          --(Wan03)
                  JOIN SERIALNO SN WITH (NOLOCK) ON SN.SerialNo = SS.SerialNo                                  --(Wan03)
                  --WHERE SN.SerialNo = @c_SerialNo                                                            --(Wan03)
                  WHERE SN.Storerkey = @c_Storerkey  --tlting                                                  --(Wan03)
                  AND SN.ExternStatus <> 'CANC'
                  AND EXISTS ( SELECT 1 FROM PACKDETAIL PD WITH (NOLOCK)
                               WHERE PD.PickSlipNo = SN.PickSlipNo   
                               AND   PD.CartonNo   = SN.CartonNo  
                               AND   PD.LabelLine  = SN.LabelLine
                             )
                  --AND SN.AddDate BETWEEN DATEADD(HH, -24, GETDATE()) AND GETDATE() 
                  AND SN.AddDate BETWEEN CONVERT(DATETIME, CONVERT(NVARCHAR(10), GETDATE(), 121))
                                 AND CONVERT(DATETIME, CONVERT(NVARCHAR(10), GETDATE(), 121) + ' 23:59:59')
               )
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 60011                                                                                           
         SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Duplicate Serial #: ' 
                      + RTRIM(@c_SerialNo) + '. SerialNo had been packed. (isp_DropIDSN01)' 
         GOTO QUIT_SP
      END
      --(Wan02) - END

      SET @b_DisableQty = 0
      --SET @c_SerialNoType = RIGHT(RTRIM(@c_SerialNo),1)         --(Wan03)

      IF @c_SerialNoType NOT IN ('M', 'C', '9', 'P')              --(Wan03)
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 60020                                                                                           
         SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Invalid Serial #. (isp_DropIDSN01)' 
         GOTO QUIT_SP
      END

      IF @c_SerialNoType = 'P'
      BEGIN 
         SET @n_Qty = @n_PLQty
         SET @b_DisableQty = 1
      END 

      IF @c_SerialNoType = 'M'
      BEGIN 
         SELECT @n_CaseCnt = PACK.CaseCnt
         FROM SKU WITH (NOLOCK)
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE SKU.Storerkey = @c_Storerkey
         AND   SKU.Sku = @c_Sku

         SET @n_Qty = @n_CaseCnt
         SET @b_DisableQty = 1
      END

      IF @c_SerialNoType = '9'
      BEGIN 
         SET @n_Qty = 1
         SET @b_DisableQty = 1
      END
   END

   -- (Wan02) - START
   IF @c_Source = 'qty' AND @n_Qty > 0 
   BEGIN
      --(Wan03) - START
      IF @c_SerialNoType IN ('P')      
      BEGIN
         IF @n_PLQty <> @n_Qty 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 60032                                                                                         
            SET @c_errmsg= 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Scanned Qty <> Pallet Count Qty. Serial#:' 
                         + RTRIM(@c_SerialNo) + '. (isp_DropIDSN01)' 
            GOTO QUIT_SP            
         END

         SELECT TOP 1 @c_Wavekey  = Wavekey  
         FROM dbo.fnc_GetWaveOrder_DropID(@c_DropID);    

         SELECT @n_QtyAllocated = ISNULL(SUM(PD.Qty),0)  
         FROM PICKDETAIL PD WITH (NOLOCK)  
         JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PD.Orderkey = WD.Orderkey)  
         WHERE PD.DropID = @c_DropID  
         AND   WD.Wavekey= @c_Wavekey  
         AND   PD.Storerkey = @c_Storerkey  
         AND   PD.Sku = @c_Sku
          
         SELECT @n_QtyPacked = ISNULL(SUM(PD.Qty),0)  
         FROM PACKHEADER PH WITH (NOLOCK)   
         JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
         JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PH.Orderkey = WD.Orderkey)  
         WHERE PD.DropID = @c_DropID  
         AND   WD.Wavekey= @c_Wavekey  
         AND   PD.Storerkey = @c_Storerkey  
         AND   PD.Sku = @c_Sku  
           
         IF @n_QtyAllocated - @n_QtyPacked > @n_PLQty
         BEGIN
            SET @n_continue = 3                                                                                              
            SET @n_err = 60070                                                                                        
            SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Pack Qty > Pick Qty. (isp_DropIDSN01)' 
                                                                                                                      
            GOTO QUIT_SP          
         END
      END
      ELSE
      BEGIN
         IF (dbo.fnc_GetOrder_DropID (@c_DropID, @c_Storerkey, @c_Sku, @n_Qty)) = ''
         BEGIN
            SET @n_continue = 3                                                                                              
            SET @n_err = 60030                                                                                        
            SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Pack Qty > Pick Qty. (isp_DropIDSN01)' 
                                                                                                                      
            GOTO QUIT_SP  
         END
      END
      --(Wan03) - END
   END
   -- (Wan02) - END

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_DropIDSN01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO