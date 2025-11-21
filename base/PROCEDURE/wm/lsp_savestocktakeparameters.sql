SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: lsp_SaveStockTakeParameters                        */  
/* Creation Date: 29-Jan-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Saving Stock Take Parms                                     */  
/*                                                                      */  
/* Called By: LFWM                                                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2021-02-25  Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/ 
CREATE PROC [WM].[lsp_SaveStockTakeParameters] (
    @c_StockTakeKey              NVARCHAR(10 ) 
   ,@c_Protect                   NVARCHAR(1  ) = 'N'
   ,@c_Password                  NVARCHAR(10 ) = ''
   ,@c_WithQuantity              NVARCHAR(1  ) = 'Y'
   ,@c_ClearHistory              NVARCHAR(1  ) = 'Y'
   ,@c_EmptyLocation             NVARCHAR(1  ) = 'Y'
   ,@n_LinesPerPage              INT           = 0          
   ,@n_FinalizeStage             INT           = 0          
   ,@n_PopulateStage             INT           = 0          
   ,@c_GroupLottable05           NVARCHAR(10 ) = ''
   ,@c_AdjReasonCode             NVARCHAR(10 ) = ''
   ,@c_AdjType                   NVARCHAR(3  ) = ''   
   ,@c_BlankCSheetHideLoc        NVARCHAR(1  ) = 'N'
   ,@n_BlankCSheetNoOfPage       INT           = 0 
   ,@c_ExcludeQtyPicked          NVARCHAR(1  ) = 'N'
   ,@c_CountType                 NVARCHAR(10 ) = ''
   ,@c_ExcludeQtyAllocated       NVARCHAR(1  ) = 'N'
   ,@c_StrategyKey               NVARCHAR(30 ) = ''
   ,@c_Parameter01               NVARCHAR(125) = ''
   ,@c_Parameter02               NVARCHAR(125) = ''
   ,@c_Parameter03               NVARCHAR(125) = ''
   ,@c_Parameter04               NVARCHAR(125) = ''
   ,@c_Parameter05               NVARCHAR(125) = ''
   ,@c_CountSheetGroupBy01       NVARCHAR(50 ) = 'LOC.PutawayZone'
   ,@c_CountSheetGroupBy02       NVARCHAR(50 ) = 'LOC.LocAisle'
   ,@c_CountSheetGroupBy03       NVARCHAR(50 ) = 'LOC.LocLevel'
   ,@c_CountSheetGroupBy04       NVARCHAR(50 ) = ''
   ,@c_CountSheetGroupBy05       NVARCHAR(50 ) = ''
   ,@c_CountSheetSortBy01        NVARCHAR(50 ) = 'LOC.CCLogicalLoc'
   ,@c_CountSheetSortBy02        NVARCHAR(50 ) = 'LOC.Loc'
   ,@c_CountSheetSortBy03        NVARCHAR(50 ) = 'LOTxLOCxID.ID'
   ,@c_CountSheetSortBy04        NVARCHAR(50 ) = 'LOTxLOCxID.Sku'
   ,@c_CountSheetSortBy05        NVARCHAR(50 ) = 'LOTxLOCxID.Lot'
   ,@c_CountSheetSortBy06        NVARCHAR(50 ) = '' 
   ,@c_CountSheetSortBy07        NVARCHAR(50 ) = '' 
   ,@c_CountSheetSortBy08        NVARCHAR(50 ) = '' 
   ,@c_QueryinJSON               NVARCHAR(4000) 
   ,@b_Success                   INT = 1 OUTPUT
   ,@n_Err                       INT = 0 OUTPUT
   ,@c_ErrMsg                    NVARCHAR(250) = '' OUTPUT
   ,@b_Debug                     INT = 0  
) AS 
BEGIN
   DECLARE 
       @c_Facility                  NVARCHAR(5  ) 
      ,@c_StorerKey                 NVARCHAR(60 ) 
      ,@c_ZoneParm                  NVARCHAR(60 ) = 'ALL'
      ,@c_AisleParm                 NVARCHAR(60 ) = 'ALL'
      ,@c_LevelParm                 NVARCHAR(60 ) = '0-99'   -- Fixed default value w/o space
      ,@c_HostWHCodeParm            NVARCHAR(60 ) = 'ALL'
      ,@c_SKUParm                   NVARCHAR(125) = 'ALL'
      ,@c_AgencyParm                NVARCHAR(125) = 'ALL' 
      ,@c_ABCParm                   NVARCHAR(60 ) = 'ALL' 
      ,@c_SkugroupParm              NVARCHAR(125) = 'ALL' 
      ,@c_ExtendedParm1Field        NVARCHAR(50 ) = ''
      ,@c_ExtendedParm1             NVARCHAR(125) = ''
      ,@c_ExtendedParm2Field        NVARCHAR(50 ) = ''
      ,@c_ExtendedParm2             NVARCHAR(125) = ''
      ,@c_ExtendedParm3Field        NVARCHAR(50 ) = ''
      ,@c_ExtendedParm3             NVARCHAR(125) = ''
      ,@n_continue                  INT = 1

   --(Wan01) - START
   BEGIN TRY
      -- Parsing the JSON Query 
      IF ISNULL(@c_QueryinJSON,'') <> ''
      BEGIN
         SET @c_StorerKey = ''
         SET @c_Facility = ''
      
         IF @c_Facility = ''
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 554201 
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                  ': Facility Paramater Not Define (lsp_SaveStockTakeParameters)'               
            GOTO EXIT_SP         
         END
      
         IF @c_StorerKey = ''
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 554202 
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                  ': Storer Paramater Not Define (lsp_SaveStockTakeParameters)'                 
            GOTO EXIT_SP         
         END
      END
   
      SET @c_ZoneParm            = ISNULL(@c_ZoneParm          , 'ALL')      
      SET @c_AisleParm           = ISNULL(@c_AisleParm         , 'ALL')      
      SET @c_LevelParm           = ISNULL(@c_LevelParm         , '0-99')            -- Fixed default value w/o space     
      SET @c_HostWHCodeParm      = ISNULL(@c_HostWHCodeParm    , 'ALL')  
      SET @c_SKUParm             = ISNULL(@c_SKUParm           , 'ALL')      
      SET @c_AgencyParm          = ISNULL(@c_AgencyParm        , 'ALL')       
      SET @c_ABCParm             = ISNULL(@c_ABCParm           , 'ALL')       
      SET @c_SkugroupParm        = ISNULL(@c_SkugroupParm      , 'ALL')       
      SET @c_ExtendedParm1Field  = ISNULL(@c_ExtendedParm1Field, '')      
      SET @c_ExtendedParm1       = ISNULL(@c_ExtendedParm1     , '')      
      SET @c_ExtendedParm2Field  = ISNULL(@c_ExtendedParm2Field, '')      
      SET @c_ExtendedParm2       = ISNULL(@c_ExtendedParm2     , '')      
      SET @c_ExtendedParm3Field  = ISNULL(@c_ExtendedParm3Field, '')      
      SET @c_ExtendedParm3       = ISNULL(@c_ExtendedParm3     , '')        
      SET @c_CountSheetGroupBy01 = ISNULL(@c_CountSheetGroupBy01, 'LOC.PutawayZone')
      SET @c_CountSheetGroupBy02 = ISNULL(@c_CountSheetGroupBy02, 'LOC.LocAisle')
      SET @c_CountSheetGroupBy03 = ISNULL(@c_CountSheetGroupBy03, 'LOC.LocLevel')
      SET @c_CountSheetGroupBy04 = ISNULL(@c_CountSheetGroupBy04, '')
      SET @c_CountSheetGroupBy05 = ISNULL(@c_CountSheetGroupBy05, '')
      SET @c_CountSheetSortBy01  = ISNULL(@c_CountSheetSortBy01 , 'LOC.CCLogicalLoc')
      SET @c_CountSheetSortBy02  = ISNULL(@c_CountSheetSortBy02 , 'LOC.Loc')
      SET @c_CountSheetSortBy03  = ISNULL(@c_CountSheetSortBy03 , 'LOTxLOCxID.ID')
      SET @c_CountSheetSortBy04  = ISNULL(@c_CountSheetSortBy04 , 'LOTxLOCxID.Sku')
      SET @c_CountSheetSortBy05  = ISNULL(@c_CountSheetSortBy05 , 'LOTxLOCxID.Lot')
      SET @c_CountSheetSortBy06  = ISNULL(@c_CountSheetSortBy06 , '') 
      SET @c_CountSheetSortBy07  = ISNULL(@c_CountSheetSortBy07 , '') 
      SET @c_CountSheetSortBy08  = ISNULL(@c_CountSheetSortBy08 , '') 
      SET @c_Protect             = ISNULL(@c_Protect,'N')
      SET @c_Password            = ISNULL(@c_Password,'' )
      SET @c_WithQuantity        = ISNULL(@c_WithQuantity,'Y')
      SET @c_ClearHistory        = ISNULL(@c_ClearHistory,'Y')
      SET @c_EmptyLocation       = ISNULL(@c_EmptyLocation,'Y')
      SET @n_LinesPerPage        = ISNULL(@n_LinesPerPage,0  )
      SET @n_FinalizeStage       = ISNULL(@n_FinalizeStage,0  )
      SET @n_PopulateStage       = ISNULL(@n_PopulateStage,0  )
      SET @c_GroupLottable05     = ISNULL(@c_GroupLottable05,'' )
      SET @c_AdjReasonCode       = ISNULL(@c_AdjReasonCode,'' )
      SET @c_AdjType             = ISNULL(@c_AdjType,'' )
      SET @c_BlankCSheetHideLoc  = ISNULL(@c_BlankCSheetHideLoc,'N')
      SET @n_BlankCSheetNoOfPage = ISNULL(@n_BlankCSheetNoOfPage,0  )
      SET @c_ExcludeQtyPicked    = ISNULL(@c_ExcludeQtyPicked,'N')
      SET @c_CountType           = ISNULL(@c_CountType,'' )
      SET @c_ExcludeQtyAllocated = ISNULL(@c_ExcludeQtyAllocated,'N')
      SET @c_StrategyKey         = ISNULL(@c_StrategyKey,'' )
      SET @c_Parameter01         = ISNULL(@c_Parameter01,'' )
      SET @c_Parameter02         = ISNULL(@c_Parameter02,'' )
      SET @c_Parameter03         = ISNULL(@c_Parameter03,'' )
      SET @c_Parameter04         = ISNULL(@c_Parameter04,'' )
      SET @c_Parameter05         = ISNULL(@c_Parameter05,'' )

      IF NOT EXISTS(SELECT 1 FROM StockTakeSheetParameters WITH (NOLOCK)
                    WHERE StockTakeKey = @c_StockTakeKey)
      BEGIN
         INSERT INTO StockTakeSheetParameters
         (
            StockTakeKey,        Facility,            StorerKey,
            ZoneParm,            AisleParm,           LevelParm,
            HostWHCodeParm,      SKUParm,             AgencyParm,
            ABCParm,             Protect,             [Password],
            WithQuantity,        ClearHistory,        EmptyLocation,
            LinesPerPage,        FinalizeStage,       PopulateStage,
            GroupLottable05,     AdjReasonCode,       AdjType,
            QueryinJSON,         BlankCSheetHideLoc,  BlankCSheetNoOfPage,
            SkugroupParm,        ExcludeQtyPicked,    CountType,
            ExtendedParm1Field,  ExtendedParm1,       ExtendedParm2Field,
            ExtendedParm2,       ExtendedParm3Field,  ExtendedParm3,
            ExcludeQtyAllocated, StrategyKey,         Parameter01,
            Parameter02,         Parameter03,         Parameter04,
            Parameter05,         CountSheetGroupBy01, CountSheetGroupBy02,
            CountSheetGroupBy03, CountSheetGroupBy04, CountSheetGroupBy05,
            CountSheetSortBy01,  CountSheetSortBy02,  CountSheetSortBy03,
            CountSheetSortBy04,  CountSheetSortBy05,  CountSheetSortBy06,
            CountSheetSortBy07,  CountSheetSortBy08)
         VALUES
         (
            @c_StockTakeKey,        @c_Facility,            @c_StorerKey,
            @c_ZoneParm,            @c_AisleParm,           @c_LevelParm,
            @c_HostWHCodeParm,      @c_SKUParm,             @c_AgencyParm,
            @c_ABCParm,             @c_Protect,             @c_Password,
            @c_WithQuantity,        @c_ClearHistory,        @c_EmptyLocation,
            @n_LinesPerPage,        @n_FinalizeStage,       @n_PopulateStage,
            @c_GroupLottable05,     @c_AdjReasonCode,       @c_AdjType,
            @c_QueryinJSON,         @c_BlankCSheetHideLoc,  @n_BlankCSheetNoOfPage,
            @c_SkugroupParm,        @c_ExcludeQtyPicked,    @c_CountType,
            @c_ExtendedParm1Field,  @c_ExtendedParm1,       @c_ExtendedParm2Field,
            @c_ExtendedParm2,       @c_ExtendedParm3Field,  @c_ExtendedParm3,
            @c_ExcludeQtyAllocated, @c_StrategyKey,         @c_Parameter01,
            @c_Parameter02,         @c_Parameter03,         @c_Parameter04,
            @c_Parameter05,         @c_CountSheetGroupBy01, @c_CountSheetGroupBy02,
            @c_CountSheetGroupBy03, @c_CountSheetGroupBy04, @c_CountSheetGroupBy05,
            @c_CountSheetSortBy01,  @c_CountSheetSortBy02,  @c_CountSheetSortBy03,
            @c_CountSheetSortBy04,  @c_CountSheetSortBy05,  @c_CountSheetSortBy06,
            @c_CountSheetSortBy07,  @c_CountSheetSortBy08)
   
      END 

   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(Wan01) - END
   EXIT_SP:

   --(Wan01) - START
   SET @b_Success = 1
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
   END  
   --(Wan01) - END     
END

GO