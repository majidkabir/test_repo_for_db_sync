SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispCCDetailUpd_MY01                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Update CCDEtail Logic                                       */  
/*                                                                      */  
/* Called from: ispCycleCount_Wrapper                                   */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 12-05-2011  1.0  ChewKP      Created                                 */  
/* 27-08-2013  1.1  Audrey      SOS287902 - Bug Fixed            (ang01)*/  
/* 27-02-2017  1.2  TLTING      Variable Nvarchar                       */  
/* 12-09-2018  1.3  Ung         WMS-6163 Add ID                         */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispCCDetailUpd_MY01]  
   @c_SKU              NVARCHAR(20),  
   @c_Storerkey        NVARCHAR(15),  
   @c_Loc              NVARCHAR(10),  
   @c_ID               NVARCHAR(18),  
   @c_CCKey            NVARCHAR(10),  
   @c_CountNo          NVARCHAR(10),  
   @c_Ref01            NVARCHAR(20),   
   @c_Ref02            NVARCHAR(20),   
   @c_Ref03            NVARCHAR(20),  
   @c_Ref04            NVARCHAR(20),  
   @c_Ref05            NVARCHAR(20),  
   @c_Qty              INT,  
   @c_Lottable01Value  NVARCHAR(18),    
   @c_Lottable02Value  NVARCHAR(18),    
   @c_Lottable03Value  NVARCHAR(18),    
   @dt_Lottable04Value DateTime,    
   @dt_Lottable05Value DateTime,   
   @c_LangCode         NVARCHAR(3),  
 @c_oFieled01        NVARCHAR(20) OUTPUT,  
 @c_oFieled02        NVARCHAR(20) OUTPUT,  
   @c_oFieled03        NVARCHAR(20) OUTPUT,  
   @c_oFieled04        NVARCHAR(20) OUTPUT,  
   @c_oFieled05        NVARCHAR(20) OUTPUT,  
   @c_oFieled06        NVARCHAR(20) OUTPUT,  
   @c_oFieled07        NVARCHAR(20) OUTPUT,  
   @c_oFieled08        NVARCHAR(20) OUTPUT,  
   @c_oFieled09        NVARCHAR(20) OUTPUT,  
   @c_oFieled10        NVARCHAR(20) OUTPUT,  
   @b_Success          INT = 1  OUTPUT,  
   @n_ErrNo            INT      OUTPUT,   
   @c_ErrMsg           NVARCHAR(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue     INT,  
           @b_debug        INT,  
           @cCCDetailKey   NVARCHAR(10),  
           @nTranCount            INT  
     
             
                
  
   SELECT @b_Success = 1, @n_ErrNo = 0, @b_debug = 0  
   SELECT @c_oFieled01  = '',  
          @c_oFieled02  = '',  
          @c_oFieled03  = '',  
          @c_oFieled04  = '',  
          @c_oFieled05  = '',  
          @c_oFieled06  = '',  
          @c_oFieled07  = '',  
          @c_oFieled08  = '',  
          @c_oFieled09  = '',  
          @c_oFieled10  = ''  
  
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN CycleCountTran  
     
   DECLARE @c_CCDetailKey        NVARCHAR(10),    
           @c_CCSheetNo          NVARCHAR(10),    
           @cExecStatements      nvarchar(4000),    
           @cExecArguments       nvarchar(4000)    
    
       
    
   -- Search ccdetail# automatically       
   IF ISNULL(@dt_Lottable04Value,'19000101') = '19000101'    
   BEGIN    
         IF ISNULL(@c_CountNo,'') = '1'    
         BEGIN    
            SET @cExecStatements = N' SELECT TOP 1   @c_CCDetailKey = c.CCDetailKey ' +    
                                       ' FROM CCDetail c WITH (NOLOCK) ' +    
                                       ' WHERE c.CCKey = @c_CCKey ' +    
                                       ' AND c.Storerkey = @c_StorerKey ' +    
                                       ' AND c.SKU = @c_SKU ' +    
                                       ' AND c.LOC = @c_LOC ' +    
               ' AND c.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01Value),'''') = '''' THEN c.Lottable01 ELSE @c_Lottable01Value END ' +    
                                       ' AND c.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02Value),'''') = '''' THEN c.Lottable02 ELSE @c_Lottable02Value END ' +    
                                       ' AND c.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03Value),'''') = '''' THEN c.Lottable03 ELSE @c_Lottable03Value END ' 
                                       --' AND c.Lottable04 IS NULL '   (ang01)
                                       --' AND c.SystemQty - c.Qty > 0 '     
          
         END    
         ELSE IF ISNULL(@c_CountNo,'') = '2'    
         BEGIN    
            SET @cExecStatements = N' SELECT TOP 1   @c_CCDetailKey = c.CCDetailKey ' +    
                                       ' FROM CCDetail c WITH (NOLOCK) ' +    
                                       ' WHERE c.CCKey = @c_CCKey ' +   
                                       ' AND c.Storerkey = @c_StorerKey ' +    
                                       ' AND c.SKU = @c_SKU ' +    
                                       ' AND c.LOC = @c_LOC ' +    
                                       ' AND c.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01Value),'''') = '''' THEN c.Lottable01 ELSE @c_Lottable01Value END ' +    
                                       ' AND c.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02Value),'''') = '''' THEN c.Lottable02 ELSE @c_Lottable02Value END ' +    
                                       ' AND c.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03Value),'''') = '''' THEN c.Lottable03 ELSE @c_Lottable03Value END ' 
                                       --' AND c.Lottable04 IS NULL'   (ang01)
                                       --' AND c.SystemQty - c.Qty_Cnt2 > 0 '     
         END    
         ELSE IF ISNULL(@c_CountNo,'') = '3'    
         BEGIN    
            SET @cExecStatements = N' SELECT TOP 1   @c_CCDetailKey = c.CCDetailKey ' +    
                                       ' FROM CCDetail c WITH (NOLOCK) ' +    
                                       ' WHERE c.CCKey = @c_CCKey ' +    
                                       ' AND c.Storerkey = @c_StorerKey ' +    
                                       ' AND c.SKU = @c_SKU ' +    
                                       ' AND c.LOC = @c_LOC ' +    
                                       ' AND c.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01Value),'''') = '''' THEN c.Lottable01 ELSE @c_Lottable01Value END ' +    
                                       ' AND c.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02Value),'''') = '''' THEN c.Lottable02 ELSE @c_Lottable02Value END ' +    
                                       ' AND c.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03Value),'''') = '''' THEN c.Lottable03 ELSE @c_Lottable03Value END ' 
                                       --' AND c.Lottable04 IS NULL '   (ang01)
                                       --' AND c.SystemQty - c.Qty_Cnt3 > 0 '     
    
         END    
    
    
         SET @cExecArguments = N'@c_CCKey          Nvarchar(10),  ' +    
                                '@c_StorerKey      Nvarchar(15),  ' +    
                                '@c_SKU            Nvarchar(20),  ' +    
                                '@c_LOC            Nvarchar(10)  , ' +    
                                '@c_CCDetailKey    Nvarchar(10) OUTPUT, ' +    
                                '@c_Lottable01Value     Nvarchar(18)   ,  ' +    
                                '@c_Lottable02Value     Nvarchar(18)   ,  ' +    
                                '@c_Lottable03Value     Nvarchar(18)     '     
                                    
    
         EXEC sp_executesql @cExecStatements, @cExecArguments,     
                                              @c_CCKey,    
                                              @c_StorerKey,     
                                              @c_SKU,     
                                              @c_LOC ,     
                                              @c_CCDetailKey OUTPUT,    
                                              @c_Lottable01Value ,     
                                              @c_Lottable02Value ,     
                                              @c_Lottable03Value        
    
   END    
   ELSE    
   BEGIN    
      IF ISNULL(@c_CountNo,'') = '1'    
         BEGIN    
            SET @cExecStatements = N' SELECT TOP 1   @c_CCDetailKey = c.CCDetailKey ' +    
                                       ' FROM CCDetail c WITH (NOLOCK) ' +    
                                       ' WHERE c.CCKey = @c_CCKey ' +    
                                       ' AND c.Storerkey = @c_StorerKey ' +    
                                       ' AND c.SKU = @c_SKU ' +    
                                       ' AND c.LOC = @c_LOC ' +    
                                       ' AND c.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01Value),'''') = '''' THEN c.Lottable01 ELSE @c_Lottable01Value END ' +    
                                       ' AND c.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02Value),'''') = '''' THEN c.Lottable02 ELSE @c_Lottable02Value END ' +    
                                       ' AND c.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03Value),'''') = '''' THEN c.Lottable03 ELSE @c_Lottable03Value END ' 
                                       --' AND c.Lottable04 = @dt_Lottable04Value '   (ang01)
                                       --' AND c.SystemQty - c.Qty > 0 '     
          
         END    
         ELSE IF ISNULL(@c_CountNo,'') = '2'    
         BEGIN    
            SET @cExecStatements = N' SELECT TOP 1   @c_CCDetailKey = c.CCDetailKey ' +    
                                       ' FROM CCDetail c WITH (NOLOCK) ' +    
                                       ' WHERE c.CCKey = @c_CCKey ' +    
                                       ' AND c.Storerkey = @c_StorerKey ' +    
                                       ' AND c.SKU = @c_SKU ' +    
                                       ' AND c.LOC = @c_LOC ' +    
                                       ' AND c.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01Value),'''') = '''' THEN c.Lottable01 ELSE @c_Lottable01Value END ' +    
                                       ' AND c.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02Value),'''') = '''' THEN c.Lottable02 ELSE @c_Lottable02Value END ' +    
                                       ' AND c.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03Value),'''') = '''' THEN c.Lottable03 ELSE @c_Lottable03Value END '    
                                       --' AND c.Lottable04 = @dt_Lottable04Value '   (ang01)
                                       --' AND c.SystemQty - c.Qty_Cnt2 > 0 '     
         END    
         ELSE IF ISNULL(@c_CountNo,'') = '3'    
         BEGIN    
            SET @cExecStatements = N' SELECT TOP 1   @c_CCDetailKey = c.CCDetailKey ' +    
                                       ' FROM CCDetail c WITH (NOLOCK) ' +    
                                       ' WHERE c.CCKey = @c_CCKey ' +    
                                       ' AND c.Storerkey = @c_StorerKey ' +    
                                       ' AND c.SKU = @c_SKU ' +    
                                       ' AND c.LOC = @c_LOC ' +    
                                       ' AND c.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01Value),'''') = '''' THEN c.Lottable01 ELSE @c_Lottable01Value END ' +    
                                       ' AND c.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02Value),'''') = '''' THEN c.Lottable02 ELSE @c_Lottable02Value END ' +    
                                       ' AND c.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03Value),'''') = '''' THEN c.Lottable03 ELSE @c_Lottable03Value END '     
                                       --' AND c.Lottable04 = @dt_Lottable04Value '   (ang01)
                                       --' AND c.SystemQty - c.Qty_Cnt3 > 0 '     
    
         END    
    
    
         SET @cExecArguments = N'@c_CCKey          Nvarchar(10),  ' +    
                                '@c_StorerKey      Nvarchar(15),  ' +    
                                '@c_SKU            Nvarchar(20),  ' +    
                                '@c_LOC            Nvarchar(10),  ' +    
                                '@c_Lottable01Value     Nvarchar(18),  ' +    
                                '@c_Lottable02Value     Nvarchar(18),  ' +    
                                '@c_Lottable03Value     Nvarchar(18),  ' +    
                                '@dt_Lottable04Value     datetime,     ' +    
                                '@c_CCDetailKey    Nvarchar(10) OUTPUT  '     
                                    
                                    
         EXEC sp_executesql @cExecStatements, @cExecArguments,     
                                              @c_CCKey,      
                                              @c_StorerKey,     
                                              @c_SKU,     
                                              @c_LOC,     
                                              @c_Lottable01Value,     
                                              @c_Lottable02Value,     
                                              @c_Lottable03Value,     
                                              @dt_Lottable04Value,    
                                              @c_CCDetailKey OUTPUT    
          
          
   END    
        
                         
   IF ISNULL(@c_CCDetailkey,'') = ''    
   BEGIN    
          
      IF ISNULL(@dt_Lottable04Value,'19000101') = '19000101'    
      BEGIN    
         SELECT TOP 1     
            @c_CCDetailKey = c.CCDetailKey     
         FROM CCDetail c (NOLOCK)    
         WHERE c.CCKey = @c_CCKey     
         AND c.Storerkey = @c_StorerKey     
         AND c.SKU = @c_SKU     
         AND c.LOC = @c_LOC     
         AND c.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01Value),'') = '' THEN c.Lottable01 ELSE @c_Lottable01Value END     
         AND c.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02Value),'') = '' THEN c.Lottable02 ELSE @c_Lottable02Value END    
         AND c.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03Value),'') = '' THEN c.Lottable03 ELSE @c_Lottable03Value END    
         --AND c.Lottable04 = CASE WHEN ISNULL(@dt_Lottable04Value,'19000101') = '19000101' THEN c.Lottable04 ELSE @dt_Lottable04Value END     
         --AND c.Lottable04 = NULL    (ang01)
         AND c.SystemQty = 0    
      END    
      --ELSE   (ang01) 
      --BEGIN    
      --   SELECT TOP 1     
      --      @c_CCDetailKey = c.CCDetailKey     
      --   FROM CCDetail c (NOLOCK)    
      --   WHERE c.CCKey = @c_CCKey     
      --   AND c.Storerkey = @c_StorerKey     
      --   AND c.SKU = @c_SKU     
      --   AND c.LOC = @c_LOC     
      --   AND c.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01Value),'') = '' THEN c.Lottable01 ELSE @c_Lottable01Value END     
      --   AND c.Lottable02 = CASE WHEN ISNULL(RTRIM(@c_Lottable02Value),'') = '' THEN c.Lottable02 ELSE @c_Lottable02Value END    
      --   AND c.Lottable03 = CASE WHEN ISNULL(RTRIM(@c_Lottable03Value),'') = '' THEN c.Lottable03 ELSE @c_Lottable03Value END    
      --   --AND c.Lottable04 = CASE WHEN ISNULL(@dt_Lottable04Value,'19000101') = '19000101' THEN c.Lottable04 ELSE @dt_Lottable04Value END     
      --   AND c.Lottable04 = @dt_Lottable04Value    
      --   AND c.SystemQty = 0    
      --END    
   END    
       
       
    
   IF ISNULL(RTRIM(@c_CCDetailKey), '') = ''    
   BEGIN    
      EXECUTE dbo.nspg_GetKey        
         @keyname ='CCDETAILKEY',         
         @fieldlength =10 ,        
         @keystring = @c_CCDetailKey OUTPUT,        
         @b_Success = @b_success OUTPUT,        
         @n_Err     = @n_ErrNo OUTPUT,        
         @c_errmsg = @c_errmsg OUTPUT        
              
      IF @b_success <> 1        
      BEGIN        
         SET @n_ErrNo = 72841        
         SET @c_errmsg = 'Get CCDetailKey Fail'        
         GOTO RollBackTran         
      END    
          
      SELECT TOP 1 @c_CCSheetNo = c.CCSheetNo      
      FROM CCDetail c (NOLOCK)    
      WHERE c.CCKey = @c_CCKey     
      AND c.Loc = @c_LOC                  
      IF ISNULL(RTRIM(@c_CCSheetNo), '') = ''    
      BEGIN    
         EXECUTE dbo.nspg_GetKey        
            'CCSheetNo',         
            10 ,        
            @c_CCSheetNo       OUTPUT,        
            @b_success        OUTPUT,        
            @n_ErrNo            OUTPUT,        
            @c_errmsg         OUTPUT        
                 
         IF @b_success <> 1        
         BEGIN        
            SET @n_ErrNo = 72842        
            SET @c_errmsg = 'Get CCSheetNo Fail'        
            GOTO RollBackTran         
         END                   
      END    
      IF ISNULL(@dt_Lottable05Value, '19000101') = '19000101'     
      BEGIN    
         SELECT TOP 1 @dt_Lottable05Value = Lottable05    
         FROM LOTATTRIBUTE l (NOLOCK)    
         WHERE l.StorerKey = @c_StorerKey     
         AND l.Sku = @c_SKU     
         ORDER BY LOT DESC      
      END    
          
      IF ISNULL(@c_CountNo,'') = '1'    
      BEGIN    
         INSERT INTO CCDETAIL (CCKey, CCDetailKey, CCSheetNo, TagNo, Storerkey, Sku, Lot,    
                     Loc, Id, SystemQty, Qty, Lottable01, Lottable02, Lottable03,    
                     Lottable04, Lottable05, FinalizeFlag, Status, Counted_Cnt1)  -- (ChewKP01)  
         VALUES (@c_CCKey, @c_CCDetailKey, @c_CCSheetNo, '', @c_StorerKey, @c_SKU,     
                 '', @c_LOC, '', 0, @c_Qty, @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value,     
                 @dt_Lottable04Value, @dt_Lottable05Value, 'N','4','1')  -- (ChewKP01)  
         IF @@ERROR <> 0        
         BEGIN        
            SET @n_ErrNo = 72843        
            SET @c_errmsg = 'INSERT CCDET fail'        
            GOTO RollBackTran        
         END       
      END               
      ELSE IF ISNULL(@c_CountNo,'') = '2'    
      BEGIN       
         INSERT INTO CCDETAIL (CCKey, CCDetailKey, CCSheetNo, TagNo, Storerkey, Sku, Lot,    
                     Loc, Id, SystemQty, Qty_Cnt2, Lottable01, Lottable02, Lottable03,    
                     Lottable04, Lottable05, FinalizeFlag, Status, Counted_Cnt2)  -- (ChewKP01)  
         VALUES (@c_CCKey, @c_CCDetailKey, @c_CCSheetNo, '', @c_StorerKey, @c_SKU,     
                 '', @c_LOC, '', 0, @c_Qty, @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value,     
                 @dt_Lottable04Value, @dt_Lottable05Value, 'N','4','1')  -- (ChewKP01)  
         IF @@ERROR <> 0        
         BEGIN        
            SET @n_ErrNo = 72847        
            SET @c_errmsg = 'INSERT CCDET fail'        
            GOTO RollBackTran        
         END               
      END     
      ELSE IF ISNULL(@c_CountNo,'') = '3'    
      BEGIN       
         INSERT INTO CCDETAIL (CCKey, CCDetailKey, CCSheetNo, TagNo, Storerkey, Sku, Lot,    
                     Loc, Id, SystemQty, Qty_Cnt3, Lottable01, Lottable02, Lottable03,    
                     Lottable04, Lottable05, FinalizeFlag, Status, Counted_Cnt3)  -- (ChewKP01)  
         VALUES (@c_CCKey, @c_CCDetailKey, @c_CCSheetNo, '', @c_StorerKey, @c_SKU,     
                 '', @c_LOC, '', 0, @c_Qty, @c_Lottable01Value, @c_Lottable02Value, @c_Lottable03Value,     
                 @dt_Lottable04Value, @dt_Lottable05Value, 'N', '4','1')  -- (ChewKP01)  
         IF @@ERROR <> 0        
         BEGIN        
            SET @n_ErrNo = 72848        
            SET @c_errmsg = 'INSERT CCDET fail'        
            GOTO RollBackTran        
         END               
      END       
                         
   END     
   ELSE    
   BEGIN    
          
      IF ISNULL(@c_CountNo,'') = '1'    
      BEGIN    
         UPDATE CCDETAIL WITH (ROWLOCK)     
            SET Qty = Qty + @c_Qty  , Status = '2'  
            , Counted_Cnt1 = '1' -- (ChewKP01)  
         WHERE CCDetailKey = @c_CCDetailKey     
             
         IF @@ERROR <> 0        
         BEGIN        
            SET @n_ErrNo = 72844        
            SET @c_errmsg = 'UPDATE CCDET fail'        
            GOTO RollBackTran        
         END       
      END    
      ELSE IF ISNULL(@c_CountNo,'') = '2'    
      BEGIN       
         UPDATE CCDETAIL WITH (ROWLOCK)     
            SET Qty_Cnt2 = Qty_Cnt2 + @c_Qty  , Status = '2'  
            , Counted_Cnt2 = '1' -- (ChewKP01)  
         WHERE CCDetailKey = @c_CCDetailKey     
             
         IF @@ERROR <> 0        
         BEGIN        
            SET @n_ErrNo = 72845        
            SET @c_errmsg = 'UPDATE CCDET fail'        
            GOTO RollBackTran        
         END      
      END    
      ELSE IF ISNULL(@c_CountNo,'') = '3'    
      BEGIN       
         UPDATE CCDETAIL WITH (ROWLOCK)     
            SET Qty_Cnt3 = Qty_Cnt3 + @c_Qty  , Status = '2'  
            , Counted_Cnt3 = '1' -- (ChewKP01)  
         WHERE CCDetailKey = @c_CCDetailKey     
             
         IF @@ERROR <> 0        
         BEGIN        
            SET @n_ErrNo = 72846        
            SET @c_errmsg = 'UPDATE CCDET fail'        
            GOTO RollBackTran        
         END      
             
      END    
   END    
     
   GOTO QUIT  
     
  
   RollBackTran:  
    ROLLBACK TRAN CycleCountTran  
  
   Quit:  
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
          COMMIT TRAN CycleCountTran  
       
  
END -- End Procedure


GO