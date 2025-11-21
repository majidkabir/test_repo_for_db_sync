SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ChannelInvHoldWrapper                               */
/* Creation Date: 26-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-9995 [CN] NIKESDC_Exceed_Hold ASN for Channel           */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-02-26  Wan01    1.1   WMS-16094 - [CN] ANFQHW_WMS_TransferAllocation*/
/* 2021-02-26  Wan02    1.1   WMS-16295 - [CN] ANF - RCM Upload HoldUnHold*/
/*                            Detail and Show HoldUnHold Qty in Channel */
/*                            Hold Module                               */
/************************************************************************/
CREATE PROC [dbo].[isp_ChannelInvHoldWrapper]
           @c_HoldType           NVARCHAR(10) 
         , @c_SourceKey          NVARCHAR(20) = ''
         , @c_SourceLineNo       NVARCHAR(20) = ''
         , @c_Facility           NVARCHAR(5)  = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_Sku                NVARCHAR(20) = ''
         , @c_Channel            NVARCHAR(20) = ''
         , @c_C_Attribute01      NVARCHAR(30) = ''
         , @c_C_Attribute02      NVARCHAR(30) = ''
         , @c_C_Attribute03      NVARCHAR(30) = ''
         , @c_C_Attribute04      NVARCHAR(30) = ''
         , @c_C_Attribute05      NVARCHAR(30) = ''
         , @n_Channel_ID         BIGINT       = 0
         , @c_Hold               NVARCHAR(1)  = '0'
         , @c_Remarks            NVARCHAR(255)= ''
         , @c_HoldTRFType        CHAR(1)      = '' --Wan01 --'F' - HOld Transfer From Channel, 'T' - HOld Transfer To Channel 
         , @n_DelQty             INT          = 0  --Wan01 --'F' - For @c_HoldType IN ('ASN', 'ADJ', 'TRF') if any   
         , @n_QtyHoldToAdj       INT          = 0  --Wan02 -- QtyHold adjusment for Hold/unhols by Channel ID only 
         , @n_ChannelTran_ID_Ref BIGINT       = 0  OUTPUT --Wan02 -- ChannelTran_ID_Ref for Import Hold/unhold by Channel ID only 
         , @b_Success            INT          = 1  OUTPUT
         , @n_Err                INT          = 0  OUTPUT
         , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT
         , @n_InvHoldKey         BIGINT       = 0  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT   = @@TRANCOUNT
         , @n_Continue              INT   = 1

         , @b_InsertHeader          BIT   = 0
         , @b_InsertDetail          BIT   = 0
         , @b_UpdateDetail          BIT   = 0

         , @n_FetchStatus           INT   = 0
         , @n_RefID                 BIGINT= 0
         , @n_Qty                   INT   = 0
         , @n_QtyOnHold             INT   = 0
         
         , @n_QtyAvailToHold        INT   = 0   --(Wan02)
         , @n_QtyHoldChannelID      INT   = 0   --(Wan02)
         , @n_RecCnt                INT   = 0   --(Wan02)
         , @n_HoldByChannelID       BIT   = 0   --(Wan02)

         , @c_DataHold              NVARCHAR(1) = '0'
         , @c_ChannelInvHold        CHAR(1)     = '0'          

         , @n_ChannelTran_ID        INT   = 0                                    --(Wan02)
         , @c_ChannelTranRefNo      NVARCHAR(20) = ''                            --(Wan02)
         , @c_SourceType            NVARCHAR(60) = 'isp_ChannelInvHoldWrapper'   --(Wan02)
         , @c_CustomerRef           NVARCHAR(30) = ''                            --(Wan02)
      
         , @c_SQL                   NVARCHAR(1000) = ''
         , @c_SQLParms              NVARCHAR(1000) = ''
         
         , @CUR_CHANNEL             CURSOR

   DECLARE @t_ChannelInv            TABLE
            (  RowId                INT         NOT NULL IDENTITY(1,1)  PRIMARY KEY
            ,  Channel_ID           BIGINT      NOT NULL DEFAULT(0)
            ,  SourceLineNo         NVARCHAR(5) NOT NULL DEFAULT('')
            ,  Qty                  INT         NOT NULL DEFAULT(0)
            ,  QtyOnHold            INT         NOT NULL DEFAULT(0)
            )

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_HoldType      = ISNULL(@c_HoldType     ,'')   
   SET @c_SourceKey     = ISNULL(@c_SourceKey    ,'')
   SET @c_SourceLineNo  = ISNULL(@c_SourceLineNo ,'')
   SET @c_Facility      = ISNULL(@c_Facility     ,'')
   SET @c_Storerkey     = ISNULL(@c_Storerkey    ,'')
   SET @c_Sku           = ISNULL(@c_Sku          ,'')
   SET @c_Channel       = ISNULL(@c_Channel      ,'')
   SET @c_C_Attribute01 = ISNULL(@c_C_Attribute01,'')
   SET @c_C_Attribute02 = ISNULL(@c_C_Attribute02,'')
   SET @c_C_Attribute03 = ISNULL(@c_C_Attribute03,'')
   SET @c_C_Attribute04 = ISNULL(@c_C_Attribute04,'')
   SET @c_C_Attribute05 = ISNULL(@c_C_Attribute05,'')
   SET @n_Channel_ID    = ISNULL(@n_Channel_ID,0)
   SET @c_Hold          = ISNULL(@c_Hold,'')
   SET @c_Remarks       = ISNULL(@c_Remarks,'')

   IF @c_Hold = ''
   BEGIN
      SET @c_Hold = '0'
   END
   
   SET @c_ChannelInvHold = @c_Hold                    --(Wan02)

   IF ( @c_SourceKey     = '' 
      ) AND 
      ( @c_Facility      = '' AND 
        @c_Storerkey     = '' AND 
        @c_Sku           = '' AND 
        @c_Channel       = '' AND 
        @c_C_Attribute01 = '' AND 
        @c_C_Attribute02 = '' AND 
        @c_C_Attribute03 = '' AND 
        @c_C_Attribute04 = '' AND 
        @c_C_Attribute05 = ''   
      ) AND
      ( @n_Channel_ID = 0 )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 70010
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) 
                    + ': Either Source Document/channel Attribute/ChannelID type is required'
                    + '. (isp_ChannelInvHoldWrapper)' 
      GOTO QUIT_SP
   END

   IF @c_HoldType IN ( '' ) 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 70020
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Hold Type: ' + @c_HoldType 
                    + '. (isp_ChannelInvHoldWrapper)' 
      GOTO QUIT_SP  
   END 

   --(Wan01) - START
   IF @c_HoldTRFType IN ( '' ) AND @c_HoldType = 'TRF'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 70022
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Hold Transfer Type: ' + @c_HoldTRFType 
                    + '. (isp_ChannelInvHoldWrapper)' 
      GOTO QUIT_SP  
   END 
   --(Wan01) - END

   IF @c_HoldType IN ( 'ASN', 'ADJ', 'TRF' ) AND @c_SourceKey = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 70030
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Souce Document # is required for Document Type' + @c_HoldType 
                    + '. (isp_ChannelInvHoldWrapper)' 
      GOTO QUIT_SP  
   END
   ELSE IF @c_HoldType = 'TRANHOLD' 
   BEGIN
      IF @c_SourceKey <> ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 70040
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Source Document Type is required'  
                       + '. (isp_ChannelInvHoldWrapper)' 
         GOTO QUIT_SP         
      END
      ELSE IF @n_Channel_ID > 0
      BEGIN
         --(Wan02) - START
         SET @n_HoldByChannelID = 1
         
         SET @n_RecCnt = 0
         SELECT @n_RecCnt = 1
            , @n_QtyAvailToHold = CINV.Qty - CINV.QtyAllocated - CINV.QtyOnHold
            , @c_Facility       = CINV.Facility     
            , @c_Storerkey      = CINV.Storerkey    
            , @c_Sku            = CINV.Sku          
            , @c_Channel        = CINV.Channel      
            , @c_C_Attribute01  = CINV.C_Attribute01
            , @c_C_Attribute02  = CINV.C_Attribute02
            , @c_C_Attribute03  = CINV.C_Attribute03
            , @c_C_Attribute04  = CINV.C_Attribute04
            , @c_C_Attribute05  = CINV.C_Attribute05
         FROM ChannelInv CINV WITH (NOLOCK) 
         WHERE CINV.Channel_ID = @n_Channel_ID
         
         IF @n_RecCnt = 0 --IF NOT EXISTS (SELECT 1 FROM ChannelInv WITH (NOLOCK) WHERE Channel_ID = @n_Channel_ID)
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 70050
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Channel ID.' 
                          + '. (isp_ChannelInvHoldWrapper)' 
            GOTO QUIT_SP
         END
         
         IF @n_QtyHoldToAdj < 0 
         BEGIN
            SELECT TOP 1 @n_QtyHoldChannelID = cid.Qty
            FROM ChannelInvHold AS cih  WITH (NOLOCK)
            JOIN ChannelInvHoldDetail AS cid WITH (NOLOCK) ON cih.InvHoldkey = cid.InvHoldkey
            WHERE cih.HoldType   = 'TranHold'
            AND   cih.SourceKey  = ''
            AND   cih.Channel_ID = @n_Channel_ID
            
            IF @n_QtyHoldChannelID + @n_QtyHoldToAdj < 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 70051
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Cannot Reduce Qty more than Hold By Channel ID Qty.' 
                             + '. (isp_ChannelInvHoldWrapper)' 
               GOTO QUIT_SP
            END
            
            IF @n_QtyHoldChannelID + @n_QtyHoldToAdj = 0
            BEGIN
               SET @c_ChannelInvHold = '0'
            END
         END
         
         IF @n_QtyHoldToAdj > @n_QtyAvailToHold
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 70052
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Qty To Hold More than Channel Available Qty.' 
                          + '. (isp_ChannelInvHoldWrapper)' 
            GOTO QUIT_SP
         END
         
         --(Wan02) - END
      END
      ELSE
      BEGIN
         IF @c_Facility  = '' OR 
            @c_Storerkey = '' OR 
            @c_Sku       = '' OR 
            @c_Channel   = '' 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 70060
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) 
                          + ': Facility, Storerkey, Sku & Channel is required for Channel Attribute hold'
                          + '. (isp_ChannelInvHoldWrapper)' 
            GOTO QUIT_SP
         END


         SET @c_SQL = N'SELECT Channel_ID'
                     + ' ,Qty = Qty - QtyOnHold'
                     + ' ,QtyOnHold = QtyOnHold'
                     + ' FROM ChannelInv WITH (NOLOCK)'
                     + ' WHERE Facility = @c_Facility'
                     + ' AND Storerkey= @c_Storerkey'
                     + ' AND Sku = @c_Sku'
                     + ' AND Channel = @c_Channel'
                     + CASE WHEN @c_C_Attribute01 = '' THEN '' ELSE ' AND C_Attribute01 = @c_C_Attribute01' END
                     + CASE WHEN @c_C_Attribute02 = '' THEN '' ELSE ' AND C_Attribute02 = @c_C_Attribute02' END
                     + CASE WHEN @c_C_Attribute03 = '' THEN '' ELSE ' AND C_Attribute03 = @c_C_Attribute03' END
                     + CASE WHEN @c_C_Attribute04 = '' THEN '' ELSE ' AND C_Attribute04 = @c_C_Attribute04' END
                     + CASE WHEN @c_C_Attribute05 = '' THEN '' ELSE ' AND C_Attribute05 = @c_C_Attribute05' END

         SET @c_SQLParms= N'@c_Facility        NVARCHAR(5)' 
                        + ',@c_Storerkey       NVARCHAR(15)'
                        + ',@c_Sku             NVARCHAR(20)'
                        + ',@c_Channel         NVARCHAR(20)'
                        + ',@c_C_Attribute01   NVARCHAR(30)'
                        + ',@c_C_Attribute02   NVARCHAR(30)'
                        + ',@c_C_Attribute03   NVARCHAR(30)'
                        + ',@c_C_Attribute04   NVARCHAR(30)'
                        + ',@c_C_Attribute05   NVARCHAR(30)'

         INSERT INTO @t_ChannelInv
            (  Channel_ID
            ,  Qty
            ,  QtyOnHold
            )
         EXEC sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms
                           ,@c_Facility        
                           ,@c_Storerkey       
                           ,@c_Sku             
                           ,@c_Channel         
                           ,@c_C_Attribute01   
                           ,@c_C_Attribute02   
                           ,@c_C_Attribute03   
                           ,@c_C_Attribute04   
                           ,@c_C_Attribute05   

         IF NOT EXISTS (SELECT 1 FROM @t_ChannelInv)
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 70060
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) 
                          + ': Channel Attribute Not Found'
                          + '. (isp_ChannelInvHoldWrapper)' 
            GOTO QUIT_SP
         END
      END
   END

   IF @c_HoldType IN ('ASN', 'ADJ', 'TRF') AND @c_SourceKey <> ''
   BEGIN
      SELECT TOP 1 @n_InvHoldKey = InvHoldKey
                  ,@c_DataHold = Hold
      FROM ChannelInvHold WITH (NOLOCK)
      WHERE HoldType  = @c_HoldType
      AND   SourceKey = @c_SourceKey

      IF @n_InvHoldKey = 0 AND @c_Hold = '0'  
      BEGIN
         GOTO QUIT_SP
      END

      IF @c_HoldType = 'ASN'
      BEGIN
         IF @c_SourceLineNo = ''
         BEGIN
            SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ChannelID = RD.Channel_ID
                     ,SourceKeyLineNo = RD.ReceiptLineNumber
                     ,Qty = RD.QtyReceived
                     ,QtyOnHold = ISNULL(CINV.QtyOnHold,0)
               FROM RECEIPTDETAIL RD WITH (NOLOCK)
               JOIN ChannelInv CINV WITH (NOLOCK)
                  ON RD.Channel_ID = CINV.Channel_ID
               WHERE RD.receiptKey = @c_SourceKey
               AND RD.FinalizeFlag = 'Y'
               AND RD.QtyReceived > 0
         END
         ELSE
         BEGIN
            SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ChannelID = RD.Channel_ID
                     ,SourceKeyLineNo = RD.ReceiptLineNumber
                     ,Qty = RD.QtyReceived
                     ,QtyOnHold = ISNULL(CINV.QtyOnHold,0)
               FROM RECEIPTDETAIL RD WITH (NOLOCK)
               JOIN ChannelInv CINV WITH (NOLOCK)
                  ON RD.Channel_ID = CINV.Channel_ID
               WHERE RD.receiptKey = @c_SourceKey
               AND   RD.ReceiptLineNumber = @c_SourceLineNo
               AND RD.FinalizeFlag = 'Y'
               AND RD.QtyReceived > 0
         END
      END
      ELSE
      IF @c_HoldType = 'ADJ'
      BEGIN
         IF @c_SourceLineNo = ''
         BEGIN
            SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ChannelID = AD.Channel_ID
                     ,SourceKeyLineNo = AD.AdjustmentLineNumber
                     ,Qty = AD.Qty
                     ,QtyOnHold = ISNULL(CINV.QtyOnHold,0)               
               FROM ADJUSTMENTDETAIL AD WITH (NOLOCK)
               JOIN ChannelInv CINV WITH (NOLOCK)
                  ON AD.Channel_ID = CINV.Channel_ID
               WHERE AD.AdjustmentKey = @c_SourceKey
               AND AD.FinalizedFlag = 'Y'
               AND AD.Qty > 0
         END
         ELSE
         BEGIN
            SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ChannelID = AD.Channel_ID
                     ,SourceKeyLineNo = AD.AdjustmentLineNumber
                     ,Qty = AD.Qty
                     ,QtyOnHold = ISNULL(CINV.QtyOnHold,0)               
               FROM ADJUSTMENTDETAIL AD WITH (NOLOCK)
               JOIN ChannelInv CINV WITH (NOLOCK)
                  ON AD.Channel_ID = CINV.Channel_ID
               WHERE AD.AdjustmentKey = @c_SourceKey
               AND   AD.AdjustmentLineNumber = @c_SourceLineNo
               AND AD.FinalizedFlag = 'Y'
               AND AD.Qty > 0
         END
      END
      ELSE
      IF @c_HoldType = 'TRF'
      BEGIN
         IF @c_SourceLineNo = ''
         BEGIN
            IF @c_HoldTRFType = 'F' 
            BEGIN            
               SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ChannelID = TD.FromChannel_ID
                     ,SourceKeyLineNo = TD.TransferLineNumber
                     ,Qty = TD.FromQty
                     ,QtyOnHold = ISNULL(CINV.QtyOnHold,0)               
               FROM TRANSFERDETAIL TD WITH (NOLOCK)
               JOIN ChannelInv CINV WITH (NOLOCK)
                  ON TD.FromChannel_ID = CINV.Channel_ID
               WHERE TD.TransferKey = @c_SourceKey
               AND TD.FromQty > 0
            END
            ELSE
            BEGIN
               SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT ChannelID = TD.ToChannel_ID
                        ,SourceKeyLineNo = TD.TransferLineNumber
                        ,Qty = TD.ToQty
                        ,QtyOnHold = ISNULL(CINV.QtyOnHold,0)               
                  FROM TRANSFERDETAIL TD WITH (NOLOCK)
                  JOIN ChannelInv CINV WITH (NOLOCK)
                     ON TD.ToChannel_ID = CINV.Channel_ID
                  WHERE TD.TransferKey = @c_SourceKey
                  AND TD.[Status] = '9'
                  AND TD.ToQty > 0
            END
         END
         ELSE
         BEGIN
            IF @c_HoldTRFType = 'F' 
            BEGIN            
               SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ChannelID = TD.FromChannel_ID
                     ,SourceKeyLineNo = TD.TransferLineNumber
                     ,Qty = TD.FromQty
                     ,QtyOnHold = ISNULL(CINV.QtyOnHold,0)               
               FROM TRANSFERDETAIL TD WITH (NOLOCK)
               JOIN ChannelInv CINV WITH (NOLOCK)
                  ON TD.FromChannel_ID = CINV.Channel_ID
               WHERE TD.TransferKey = @c_SourceKey
               AND TD.TransferLineNumber = @c_SourceLineNo
               AND TD.FromQty > 0
               UNION                                        --For Delete Transfer Line
               SELECT ChannelID = @n_Channel_ID
                     ,SourceKeyLineNo = @c_SourceLineNo
                     ,Qty = @n_DelQty
                     ,QtyOnHold = ISNULL(CINV.QtyOnHold,0)               
               FROM ChannelInv CINV WITH (NOLOCK)
               WHERE CINV.Channel_ID = @n_Channel_ID
            END
            ELSE
            BEGIN
               SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT ChannelID = TD.ToChannel_ID
                        ,SourceKeyLineNo = TD.TransferLineNumber
                        ,Qty = TD.ToQty
                        ,QtyOnHold = ISNULL(CINV.QtyOnHold,0)               
                  FROM TRANSFERDETAIL TD WITH (NOLOCK)
                  JOIN ChannelInv CINV WITH (NOLOCK)
                     ON TD.ToChannel_ID = CINV.Channel_ID
                  WHERE TD.TransferKey = @c_SourceKey
                  AND TD.TransferLineNumber = @c_SourceLineNo
                  AND TD.[Status] = '9'
                  AND TD.ToQty > 0
            END
         END
      END
   END
   ELSE
   BEGIN
      IF @n_Channel_ID > 0 
      BEGIN
         SELECT TOP 1 
                  @n_InvHoldKey = HH.InvHoldKey
               ,  @c_DataHold = HH.Hold
         FROM ChannelInvHold HH WITH (NOLOCK)
         INNER JOIN ChannelInvHoldDetail HD WITH (NOLOCK)
            ON HH.InvHoldKey = HD.InvHoldkey
         WHERE HH.HoldType   = 'TranHold'
         AND   HH.SourceKey  = ''
         AND   HH.Channel_ID = @n_Channel_ID

         SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ChannelID = @n_Channel_ID
                  ,SourceKeyLineNo = ''
                  ,Qty       = @n_QtyHoldToAdj           --(Wan02)
                  ,QtyOnHold = QtyOnHold
            FROM CHANNELINV WITH (NOLOCK)
            WHERE Channel_ID = @n_Channel_ID
      END 
      ELSE
      BEGIN 
         SELECT TOP 1 
                  @n_InvHoldKey = HH.InvHoldKey
               ,  @c_DataHold = HH.Hold
         FROM ChannelInvHold HH WITH (NOLOCK)
         WHERE HH.HoldType      = 'TranHold' 
         AND   HH.SourceKey     = ''
         AND   HH.Facility      = @c_Facility
         AND   HH.Storerkey     = @c_Storerkey
         AND   HH.Sku           = @c_Sku
         AND   HH.Channel       = @c_Channel
         AND   HH.C_Attribute01 = @c_C_Attribute01
         AND   HH.C_Attribute02 = @c_C_Attribute02
         AND   HH.C_Attribute03 = @c_C_Attribute03
         AND   HH.C_Attribute04 = @c_C_Attribute04
         AND   HH.C_Attribute05 = @c_C_Attribute05
         AND   HH.Channel_ID    = 0

         SET @CUR_CHANNEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Channel_ID  
                  ,SourceLineNo 
                  ,Qty  
                  ,QtyOnHold 
            FROM @t_ChannelInv
            ORDER BY RowId
      END
   END

   IF @n_InvHoldKey = 0       --Insert for 1) ASN,ADJ,TRF and hold='1' 2) for TRANHOLD and Hold = '0' / '1' 
   BEGIN
      SET @b_InsertHeader = 1
      INSERT INTO ChannelInvHold 
         (
            HoldType
         ,  Sourcekey
         ,  Facility
         ,  Storerkey
         ,  Sku
         ,  Channel 
         ,  C_Attribute01
         ,  C_Attribute02
         ,  C_Attribute03
         ,  C_Attribute04
         ,  C_Attribute05
         ,  Channel_ID
         ,  Hold
         ,  Remarks
         )
      VALUES
         (
            @c_HoldType
         ,  @c_Sourcekey
         ,  @c_Facility
         ,  @c_Storerkey
         ,  @c_Sku
         ,  @c_Channel
         ,  @c_C_Attribute01
         ,  @c_C_Attribute02
         ,  @c_C_Attribute03
         ,  @c_C_Attribute04
         ,  @c_C_Attribute05 
         ,  @n_Channel_ID      
         ,  @c_Hold
         ,  @c_Remarks
         )
      SET @n_Err = @@ERROR

      IF @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 70070
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Insert record Into ChannelInvHold table fail.'
                       + '. (isp_ChannelInvHoldWrapper)' 
         GOTO QUIT_SP
      END
   
      SET @n_InvHoldKey = @@IDENTITY
   END
   ELSE IF @n_InvHoldKey > 0
   BEGIN
      UPDATE ChannelInvHold 
      SET Hold = @c_Hold
         ,DateOn  = CASE WHEN @c_ChannelInvHold  = '1' THEN GETDATE()    ELSE DateOn END     --(Wan02)
         ,WhoOn   = CASE WHEN @c_ChannelInvHold  = '1' THEN SUSER_NAME() ELSE WhoOn END      --(Wan02)
         ,DateOff = CASE WHEN @c_ChannelInvHold  = '0' THEN GETDATE()    ELSE DateOff END    --(Wan02) 
         ,WhoOff  = CASE WHEN @c_ChannelInvHold  = '0' THEN SUSER_NAME() ELSE WhoOff END     --(Wan02)
         ,Remarks = @c_Remarks
      WHERE InvHoldKey = @n_InvHoldKey

      SET @n_Err = @@ERROR

      IF @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 70080
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Update record Into ChannelInvHold table fail.'
                        + '. (isp_ChannelInvHoldWrapper)' 
         GOTO QUIT_SP
      END
   END

   OPEN @CUR_CHANNEL
   FETCH NEXT FROM @CUR_CHANNEL INTO @n_Channel_ID, @c_SourceLineNo, @n_Qty, @n_QtyOnHold

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_RefID       = 0
      SET @b_InsertDetail= 0
      SET @b_UpdateDetail= 0  
      IF @b_InsertHeader = 1
      BEGIN
         SET @b_InsertDetail= 1
      END
      ELSE
      BEGIN
         SELECT TOP 1 @n_RefID = RefID
               ,@n_Qty = CASE WHEN @c_Hold = '0' AND @n_HoldByChannelID = 0 THEN Qty ELSE @n_Qty END  -- (Wan02)
         FROM ChannelInvHoldDetail WITH (NOLOCK)
         WHERE InvHoldkey  = @n_InvHoldkey
         AND   SourceLineNo= @c_SourceLineNo
         AND   Channel_ID  = @n_Channel_ID

         IF @n_Qty > 0 AND @n_QtyOnHold > 0 AND @n_Qty > @n_QtyOnHold AND @c_Hold = '0'
         BEGIN
            SET @n_Qty = @n_QtyOnHold
         END

         IF @n_RefID = 0  
         BEGIN
            SET @b_InsertDetail= 1
         END
         ELSE IF @n_RefID > 0  
         BEGIN
            SET @b_UpdateDetail = 1
         END
      END

      IF @b_InsertDetail= 1 
      BEGIN
         INSERT INTO ChannelInvHoldDetail
            (
               InvHoldKey
            ,  SourceLineNo
            ,  Channel_ID
            ,  Qty
            ,  Hold
            )
         VALUES
            (
               @n_InvHoldKey
            ,  @c_SourceLineNo
            ,  @n_Channel_ID
            ,  @n_Qty
            ,  @c_Hold
            )

         SET @n_Err = @@ERROR

         IF @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 70090
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Insert record Into ChannelInvHoldDetail table fail.'
                          + '. (isp_ChannelInvHoldWrapper)' 
            GOTO QUIT_SP
         END
         SET @n_RefID = SCOPE_IDENTITY()  
      END 

      IF @b_UpdateDetail = 1 
      BEGIN
         UPDATE ChannelInvHoldDetail
         SET Hold = @c_Hold
            ,Qty  = CASE WHEN @c_Hold  = '1' THEN Qty ELSE 0 END + @n_Qty                       --(Wan02)
            ,DateOn  = CASE WHEN @c_ChannelInvHold  = '1' THEN GETDATE()    ELSE DateOn END     --(Wan02)
            ,WhoOn   = CASE WHEN @c_ChannelInvHold  = '1' THEN SUSER_NAME() ELSE WhoOn END      --(Wan02)
            ,DateOff = CASE WHEN @c_ChannelInvHold  = '0' THEN GETDATE()    ELSE DateOff END    --(Wan02) 
            ,WhoOff  = CASE WHEN @c_ChannelInvHold  = '0' THEN SUSER_NAME() ELSE WhoOff END     --(Wan02)
         WHERE RefID = @n_RefID

         SET @n_Err = @@ERROR

         IF @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 70100
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Update record Into ChannelInvHoldDetail table fail.'
                          + '. (isp_ChannelInvHoldWrapper)' 
            GOTO QUIT_SP
         END
      END

      IF @c_Hold = '0' AND @n_Qty > 0                                            --(Wan02)
      BEGIN
         SET @n_Qty = -1 * @n_Qty
      END 

      UPDATE CHANNELINV 
      SET QtyOnHold= QtyOnHold + @n_Qty
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()
      WHERE Channel_ID = @n_Channel_ID
      AND QtyOnHold + @n_Qty >= 0

      SET @n_Err = @@ERROR

      IF @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 70110
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Update record Into CHANNELINV table fail.'
                        + '. (isp_ChannelInvHoldWrapper)' 
         GOTO QUIT_SP
      END
      
      ------------------------------------------------------------
      -- Log ChannelInvHoldDetail's Channel to CHANNELTRAN - START
      ------------------------------------------------------------
      
      SET @c_ChannelTranRefNo = CONVERT(NVARCHAR(10), @n_RefID)
      SET @c_SourceType = 'isp_ChannelInvHoldWrapper'
      SET @c_CustomerRef = @c_Remarks   
      INSERT INTO CHANNELITRAN  
            (  
            TranType,            ChannelTranRefNo,       SourceType,  
            StorerKey,           SKU,                    Facility,  
            Channel_ID,          Channel,  
            C_Attribute01,       C_Attribute02,          C_Attribute03,  
            C_Attribute04,       C_Attribute05,  
            Qty,                 QtyOnHold,  
            Reasoncode,          CustomerRef  
            )  
      SELECT   'HOLD',              @c_ChannelTranRefNo, @c_SourceType,  
               ci.StorerKey,        ci.SKU,              ci.Facility,     
               ci.Channel_ID,       ci.Channel,  
               ci.C_Attribute01,    ci.C_Attribute02,    ci.C_Attribute03,  
               ci.C_Attribute04,    ci.C_Attribute05,  
               @n_Qty,              0,  
               '',                  @c_CustomerRef  
      FROM ChannelInv AS ci WITH (NOLOCK)
      WHERE ci.Channel_ID = @n_Channel_ID
      
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err      = 70120  
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Insert Into CHANNELITRAN fail'  
                         + '. (isp_ChannelInvHoldWrapper)'  
         GOTO QUIT_SP  
      END  
      
      SET @n_ChannelTran_ID = SCOPE_IDENTITY()  
      
      IF @n_ChannelTran_ID_Ref = 0
      BEGIN
         SET @n_ChannelTran_ID_Ref = @n_ChannelTran_ID 
      END   
           
      UPDATE CHANNELITRAN
         SET CustomerRef = CONVERT(NVARCHAR(10),@n_ChannelTran_ID_Ref) + ' ' + CustomerRef
            ,EditWho = SUSER_SNAME()
            ,EditDate= GETDATE()
            ,TrafficCop = NULL
      WHERE ChannelTran_ID = @n_ChannelTran_ID
         
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err      = 70130  
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update Into CHANNELITRAN fail'  
                         + '. (isp_ChannelInvHoldWrapper)'  
         GOTO QUIT_SP  
      END  
      
      ------------------------------------------------------------
      -- Log ChannelInvHoldDetail's Channel to CHANNELTRAN - END
      ------------------------------------------------------------ 

      FETCH NEXT FROM @CUR_CHANNEL INTO @n_Channel_ID, @c_SourceLineNo, @n_Qty, @n_QtyOnHold
   END 
   CLOSE @CUR_CHANNEL
   DEALLOCATE @CUR_CHANNEL

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ChannelInvHoldWrapper'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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